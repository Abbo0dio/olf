import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/prediction/prediction_format.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  DateTime daysAgo(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: n));
  }

  /// A 4-day period starting on [start] — closed, so several can be seeded
  /// without the open-ended-overlap rule rejecting them.
  Future<void> seedStart(AppDatabase db, DateTime start) =>
      DriftPeriodRepository(db).addPeriod(
        PeriodDraft(start: start, end: start.add(const Duration(days: 3))),
      );

  /// The prediction the screen will compute, for cross-checking rendered text.
  /// p3.6: the production engine is `AdaptivePredictor` now, so this oracle is
  /// too — the asserted dates/ranges/confidence below are v2's output.
  CyclePrediction predictionFor(List<DateTime> starts) =>
      const AdaptivePredictor().predict(
        cycles: deriveCycles([
          for (final s in starts)
            Period(
              id: starts.indexOf(s) + 1,
              startDate: s,
              endDate: null,
              createdAt: s,
              updatedAt: s,
            ),
        ]),
        today: DateTime.now(),
      )!;

  testWidgets('a regular history renders next-period and fertile ranges', (
    tester,
  ) async {
    // p3.6: v2 needs ~4 completed cycles of steady evidence (effective sample
    // ≥ 3) before it will call a forecast "high confidence"; v1 reached it at 3.
    // Same intent — a strong regular history renders the confident-estimate
    // path — with one more metronomic cycle so v2 legitimately gets there.
    final starts = [
      daysAgo(132),
      daysAgo(104),
      daysAgo(76),
      daysAgo(48),
      daysAgo(20),
    ];
    final db = memoryDb();
    for (final s in starts) {
      await seedStart(db, s);
    }
    final p = predictionFor(starts);
    expect(p.status, PredictionStatus.upcoming); // sanity on the fixture
    expect(p.confidence, PredictionConfidence.high);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        expect(find.text('Next period'), findsOneWidget);
        expect(find.text(formatDateRange(p.nextPeriod)), findsOneWidget);
        expect(find.text('Fertile window (estimate)'), findsOneWidget);
        expect(find.text(formatDateRange(p.fertileWindow)), findsOneWidget);
        expect(find.textContaining('Most likely'), findsOneWidget);
        expect(find.text('Confident estimate'), findsOneWidget);
        expect(find.textContaining('Based on'), findsOneWidget);
      },
    );
  });

  testWidgets('a late period shows a check-in, not a rolled-forward date', (
    tester,
  ) async {
    final starts = [daysAgo(101), daysAgo(73), daysAgo(45)];
    final db = memoryDb();
    for (final s in starts) {
      await seedStart(db, s);
    }
    final p = predictionFor(starts);
    expect(p.status, PredictionStatus.overdue); // sanity

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        expect(find.text('Period check-in'), findsOneWidget);
        expect(find.textContaining('later than usual'), findsOneWidget);
        // the forecast half is not shown while overdue
        expect(find.text('Next period'), findsNothing);
        expect(find.textContaining('Fertile window'), findsNothing);

        // and it offers a direct way to log the real start
        await tester.tap(find.text('Log period start'));
        await tester.pumpAndSettle();
        expect(find.text('Log a period'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('editing history updates the prediction on the same screen', (
    tester,
  ) async {
    final db = memoryDb();
    await seedStart(db, daysAgo(34));
    await seedStart(db, daysAgo(6));

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        expect(find.text('Next period'), findsOneWidget);

        // remove the most recent period → only one left → nothing to predict
        await tester.tap(find.byTooltip('Delete period').first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Next period'), findsNothing);
        expect(find.text('Period check-in'), findsNothing);
      },
    );
  });

  testWidgets('one logged period → no prediction card yet', (tester) async {
    final db = memoryDb();
    await seedStart(db, daysAgo(4));

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        expect(find.text('Next period'), findsNothing);
        expect(find.text('Period check-in'), findsNothing);
        expect(find.textContaining('Log at least two periods'), findsOneWidget);
      },
    );
  });
}
