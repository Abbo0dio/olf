import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/prediction/accuracy_format.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  Future<void> seed(AppDatabase db, DateTime start) =>
      DriftPeriodRepository(db).addPeriod(
        PeriodDraft(start: start, end: start.add(const Duration(days: 3))),
      );

  /// ~10 monthly starts with mild variation, so the metrics are non-trivial.
  List<DateTime> historyStarts() {
    const gaps = [28, 30, 27, 29, 28, 31, 27, 28, 30, 28];
    var d = DateTime(2025, 1, 5);
    final out = <DateTime>[d];
    for (final g in gaps) {
      d = d.add(Duration(days: g));
      out.add(d);
    }
    return out;
  }

  Future<void> openAccuracy(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(accuracySettingsTitle),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(accuracySettingsTitle));
    // The screen replays the whole history behind its own spinner — flush,
    // don't pumpAndSettle (the spinner animates forever).
    await flush(tester, 20);
    expect(find.widgetWithText(AppBar, accuracyScreenTitle), findsOneWidget);
  }

  testWidgets('metrics match the core backtest on the same history', (
    tester,
  ) async {
    final db = memoryDb();
    final starts = historyStarts();
    for (final s in starts) {
      await seed(db, s);
    }

    // Oracle: the exact numbers the screen should show.
    final run = runBacktest(
      periodStarts: starts,
      predictor: const RobustPredictor(),
      minCompletedCycles: 1,
    );
    final m = BacktestMetrics.of(run);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await openAccuracy(tester);

        expect(find.text(accuracyThinHistory), findsNothing);
        expect(find.text(accuracySampleSize(m.scoredPoints)), findsOneWidget);
        expect(find.text(accuracyDays(m.meanAbsErrorDays)), findsWidgets);
        expect(find.text(accuracyDays(m.medianAbsErrorDays)), findsWidgets);
        expect(find.text(accuracyPercent(m.coverage)), findsOneWidget);
        expect(find.text(accuracyPrivacyNote), findsOneWidget);
        // The sparkline is drawn (a CustomPaint with our painter).
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is CustomPaint &&
                w.painter.runtimeType.toString().contains('Sparkline'),
          ),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('thin history → keep-logging prompt, never a fabricated number', (
    tester,
  ) async {
    final db = memoryDb();
    await seed(db, DateTime(2025, 1, 5));
    await seed(db, DateTime(2025, 2, 3));

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await openAccuracy(tester);

        expect(find.text(accuracyThinHistory), findsOneWidget);
        expect(find.text(accuracyPrivacyNote), findsOneWidget);
        // No metric tiles, no sample-size line.
        expect(find.text(accuracyTypicalMissLabel), findsNothing);
        expect(find.text(accuracyInRangeLabel), findsNothing);
      },
    );
  });

  testWidgets('the accuracy path constructs no HttpClient', (tester) async {
    // flutter_test re-installs its own mock override at the start of every test,
    // so clearing it afterwards is enough.
    HttpOverrides.global = _NoNetworkOverrides();
    addTearDown(() => HttpOverrides.global = null);

    final db = memoryDb();
    for (final s in historyStarts()) {
      await seed(db, s);
    }

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await openAccuracy(tester);
        // If anything on this path had reached for the network, creating the
        // client would have thrown before we got here.
        expect(find.text(accuracyPrivacyNote), findsOneWidget);
        expect(find.text(accuracySampleSize(_expectedScored)), findsOneWidget);
      },
    );
  });
}

/// Scored-point count for [historyStarts] via `minCompletedCycles: 1`:
/// k runs 1..(n-2) → n-2 points, n = 11 → 9.
const int _expectedScored = 9;

class _NoNetworkOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => throw StateError(
    'the prediction-accuracy screen must not open an HttpClient',
  );
}
