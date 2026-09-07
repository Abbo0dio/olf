import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/prediction/prediction_format.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  final today = DateTime(2026, 6, 20);
  DateTime daysAgo(int n) => today.subtract(Duration(days: n));

  /// Four closed ~28-day periods, the most recent starting 22 days before
  /// [today] — enough history for a non-null forecast and a drawable phase.
  Future<void> seedHistory(AppDatabase db) async {
    final periods = DriftPeriodRepository(db);
    for (final startAgo in const [22, 50, 78, 106, 134]) {
      await periods.addPeriod(
        PeriodDraft(start: daysAgo(startAgo), end: daysAgo(startAgo - 3)),
      );
    }
  }

  /// Passive sleeping-wrist readings for the open cycle: low ~36.30 for the
  /// first 13 days, then a +0.35 step through today.
  Future<void> seedPassiveShift(AppDatabase db) async {
    final bbt = DriftBbtRepository(db, now: () => today);
    for (var d = 0; d <= 22; d++) {
      final day = daysAgo(22 - d);
      final elevated = d >= 13;
      await bbt.setTemp(
        day,
        36.30 + (elevated ? 0.35 : 0.0) + ((d * 37) % 7 - 3) * 0.01,
        source: HealthDataSource.appleHealth,
        externalId: 'w$d',
        measurementKind: BbtMeasurementKind.sleepingWrist,
      );
    }
  }

  testWidgets('the passive-shift caption renders under the wheel once a shift '
      'is confirmed', (tester) async {
    final db = memoryDb();
    await seedHistory(db);
    await seedPassiveShift(db);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        expect(
          find.textContaining("you're past ovulation for this cycle"),
          findsOneWidget,
        );
        expect(find.textContaining('estimate'), findsWidgets);
      },
    );
  });

  testWidgets('no passive temperature data → no caption, wheel unchanged', (
    tester,
  ) async {
    final db = memoryDb();
    await seedHistory(db);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        expect(
          find.textContaining("you're past ovulation for this cycle"),
          findsNothing,
        );
        // the wheel itself still renders (a phase label is shown)
        expect(find.text('Log a period to see this'), findsNothing);
      },
    );
  });

  testWidgets('"Reduce spoken detail" redacts the caption for screen readers', (
    tester,
  ) async {
    final db = memoryDb();
    await seedHistory(db);
    await seedPassiveShift(db);
    await DriftSettingsRepository(
      db,
    ).set(SettingKeys.reduceSpokenDetail, 'true');

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        final caption = find.textContaining(
          "you're past ovulation for this cycle",
        );
        expect(caption, findsOneWidget);
        final widget = tester.widget<Text>(caption);
        expect(widget.semanticsLabel, passivePhaseNoteRedacted);
      },
    );
  });

  testWidgets('the wheel is still correctable — tapping it opens quick-log', (
    tester,
  ) async {
    final db = memoryDb();
    await seedHistory(db);
    await seedPassiveShift(db);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await tester.tap(find.bySemanticsLabel(RegExp('Cycle phase wheel')));
        await tester.pumpAndSettle();
        // the today quick-log sheet is up
        expect(find.text('Spotting'), findsOneWidget);
      },
    );
  });
}
