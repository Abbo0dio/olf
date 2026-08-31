import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/prediction/prediction_format.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

/// p3.3 — the visible correction loop. When the user fixes a logged date (or
/// adds / removes a period), the screen must *show* that the correction landed
/// and what moved — never silently. The note's wording comes verbatim from the
/// core [PredictionDelta]; these tests assert the screen renders exactly that,
/// recomputed from the corrected history, and announces it to screen readers.
void main() {
  DateTime daysAgo(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: n));
  }

  String usDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}/${d.year}';

  /// A 4-day period starting on [start] — closed so several seed cleanly.
  Future<void> seedStart(AppDatabase db, DateTime start) =>
      DriftPeriodRepository(db).addPeriod(
        PeriodDraft(start: start, end: start.add(const Duration(days: 3))),
      );

  /// The engine's prediction for a set of period start dates — the oracle the
  /// rendered note and card are checked against. p3.6: production is
  /// `AdaptivePredictor` now, so the oracle (and the delta reasons derived from
  /// it) are v2's.
  CyclePrediction? predictionFor(List<DateTime> starts) =>
      const AdaptivePredictor().predict(
        cycles: deriveCycles([
          for (var i = 0; i < starts.length; i++)
            Period(
              id: i + 1,
              startDate: starts[i],
              endDate: starts[i].add(const Duration(days: 3)),
              createdAt: starts[i],
              updatedAt: starts[i],
            ),
        ]),
        today: DateTime.now(),
      );

  /// Open the editor on the most recent history row and retype its start date.
  Future<void> correctMostRecentStartTo(
    WidgetTester tester,
    DateTime to,
  ) async {
    await tester.tap(find.byTooltip('Edit period').first);
    await tester.pumpAndSettle();
    expect(find.text('Edit period'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    // Switch the date picker to keyboard entry so the test doesn't have to
    // navigate a calendar grid across month boundaries.
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), usDate(to));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('correcting a logged start shows what changed, recomputed', (
    tester,
  ) async {
    final original = [daysAgo(104), daysAgo(76), daysAgo(48), daysAgo(20)];
    final corrected = [...original]..[3] = daysAgo(13);

    final before = predictionFor(original);
    final after = predictionFor(corrected);
    final expected = PredictionDelta.between(
      before: before,
      after: after,
      context: const PredictionChangeContext(followedCorrection: true),
    );
    // Sanity on the fixture: this correction actually moves the forecast.
    expect(expected.isMeaningful, isTrue);
    expect(after, isNotNull);

    final db = memoryDb();
    for (final s in original) {
      await seedStart(db, s);
    }

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        expect(find.text('Next period'), findsOneWidget);

        await correctMostRecentStartTo(tester, daysAgo(13));

        // The note renders every line the core produced, verbatim...
        for (final reason in expected.reasons) {
          expect(
            find.text(reason),
            findsOneWidget,
            reason: 'missing correction-note line: "$reason"',
          );
        }
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

        // ...and the prediction card now reflects the engine run on the
        // corrected history, not the old one.
        expect(find.text(formatDateRange(after!.nextPeriod)), findsOneWidget);
        if (before != null) {
          expect(find.text(formatDateRange(before.nextPeriod)), findsNothing);
        }

        // Nothing alarming in the surfaced copy.
        for (final reason in expected.reasons) {
          for (final banned in const [
            'wrong',
            'error',
            'mistake',
            'invalid',
            'failed',
          ]) {
            expect(reason.toLowerCase(), isNot(contains(banned)));
          }
        }

        await tester.tap(find.byTooltip('Dismiss'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      },
    );
  });

  testWidgets(
    'a correction that changes nothing still says so — never silent',
    (tester) async {
      final starts = [daysAgo(112), daysAgo(84), daysAgo(56), daysAgo(28)];

      final before = predictionFor(starts);
      final after = predictionFor(starts); // identical history → identical run
      final expected = PredictionDelta.between(
        before: before,
        after: after,
        context: const PredictionChangeContext(followedCorrection: true),
      );
      expect(expected.isMeaningful, isFalse);
      expect(expected.reasons, [
        'Your correction was applied. The prediction did not need to change.',
      ]);

      final db = memoryDb();
      for (final s in starts) {
        await seedStart(db, s);
      }

      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          expect(find.text('Next period'), findsOneWidget);

          // Re-save the most recent period without touching its dates.
          await tester.tap(find.byTooltip('Edit period').first);
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'Save'));
          await tester.pumpAndSettle();

          expect(
            find.text(
              'Your correction was applied. '
              'The prediction did not need to change.',
            ),
            findsOneWidget,
          );
          expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

          await tester.tap(find.byTooltip('Dismiss'));
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.check_circle_outline), findsNothing);
        },
      );
    },
  );

  testWidgets('logging a new period says "logged", never "corrected"', (
    tester,
  ) async {
    // One period on file → no forecast yet. Logging a second is *adding* data,
    // not correcting it: the note must use the cyclesAdded wording.
    final existing = daysAgo(28);
    final db = memoryDb();
    await seedStart(db, existing);

    final expected = PredictionDelta.between(
      before: predictionFor([existing]),
      after: predictionFor([existing, daysAgo(0)]),
      context: const PredictionChangeContext(cyclesAdded: 1),
    );
    expect(expected.reasons, isNotEmpty);
    expect(expected.reasons.first, startsWith('You logged another cycle.'));

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        expect(find.text('Next period'), findsNothing);

        await tester.tap(find.text('Add a period'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();

        for (final reason in expected.reasons) {
          expect(find.text(reason), findsOneWidget);
          expect(reason.toLowerCase(), isNot(contains('correct')));
        }
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

        await tester.tap(find.byTooltip('Dismiss'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('logging the first-ever period still renders a non-empty note', (
    tester,
  ) async {
    final db = memoryDb();

    final expected = PredictionDelta.between(
      before: null,
      after: null,
      context: const PredictionChangeContext(cyclesAdded: 1),
    );
    expect(expected.isMeaningful, isFalse);
    expect(expected.reasons, isNotEmpty);
    expect(expected.reasons.single.toLowerCase(), isNot(contains('correct')));

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await tester.tap(find.text('Add a period'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();

        expect(find.text(expected.reasons.single), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

        await tester.tap(find.byTooltip('Dismiss'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('the note is a live region and is announced to screen readers', (
    tester,
  ) async {
    final announced = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
      SystemChannels.accessibility,
      (message) async {
        if (message is Map && message['type'] == 'announce') {
          announced.add((message['data'] as Map)['message'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
        SystemChannels.accessibility,
        null,
      ),
    );

    final original = [daysAgo(104), daysAgo(76), daysAgo(48), daysAgo(20)];
    final corrected = [...original]..[3] = daysAgo(13);
    final expected = PredictionDelta.between(
      before: predictionFor(original),
      after: predictionFor(corrected),
      context: const PredictionChangeContext(followedCorrection: true),
    );

    final db = memoryDb();
    for (final s in original) {
      await seedStart(db, s);
    }

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await correctMostRecentStartTo(tester, daysAgo(13));

        // The note is its own live region (distinct from the transient
        // "Period saved." SnackBar, which is also a live region).
        final live = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.liveRegion ?? false) &&
              (w.properties.label?.contains('Your correction was applied.') ??
                  false),
        );
        expect(live, findsOneWidget);

        expect(announced, contains(expected.reasons.join(' ')));

        await tester.tap(find.byTooltip('Dismiss'));
        await tester.pumpAndSettle();
      },
    );
  });
}
