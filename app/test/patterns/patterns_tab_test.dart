import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/bbt/bbt_chart_widget.dart';
import 'package:olf_app/src/modes/correlation_chart.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

/// r3b — the Patterns tab hosts the longer-term views moved off the Home scroll
/// and out of Settings: prediction accuracy, the cycle-stats card, per-cycle
/// BBT history, symptom × cycle-phase correlations, and the mode entries. Every
/// section degrades to an existing empty / keep-logging state on thin data.
void main() {
  final today = DateTime.now();
  DateTime daysAgo(int n) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: n));

  /// A regular history (three complete 28-day cycles + the open one), basal
  /// readings across the open cycle, and a symptom logged across cycle phases —
  /// enough for every Patterns section to render.
  Future<void> seedRich(AppDatabase db) async {
    final periods = DriftPeriodRepository(db);
    for (final ago in const [112, 84, 56, 28]) {
      await periods.addPeriod(
        PeriodDraft(start: daysAgo(ago), end: daysAgo(ago - 3)),
      );
    }
    final bbt = DriftBbtRepository(db);
    for (var d = 0; d <= 18; d++) {
      await bbt.setTemp(daysAgo(20 - d), 36.35 + (d >= 10 ? 0.30 : 0.0));
    }
    final symptoms = DriftSymptomRepository(db);
    final cramps = (await symptoms.activeTypes()).firstWhere(
      (t) => t.name == 'Cramps',
    );
    for (final ago in const [90, 88, 86, 62, 60, 58, 34, 32, 30]) {
      await symptoms.setSymptom(daysAgo(ago), cramps.id, present: true);
    }
  }

  testWidgets('rich data — every section renders', (tester) async {
    final db = memoryDb();
    await seedRich(db);
    await DriftSettingsRepository(
      db,
    ).set(LifeStageMode.pcos.settingKey, 'true');

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await switchTab(tester, 'Patterns');

        // Prediction accuracy — a row into the accuracy screen.
        expect(find.text('Prediction accuracy'), findsOneWidget);

        // Cycle stats card, expanded from the Home tab.
        expect(find.text('Your cycles'), findsOneWidget);
        expect(find.text('28-day typical cycle'), findsOneWidget);

        // BBT history — a per-cycle chart, labelled.
        expect(find.text('Basal temperature'), findsOneWidget);
        expect(find.text('This cycle'), findsOneWidget);
        expect(find.byType(BbtChart), findsWidgets);

        // Symptom × cycle-phase correlations.
        expect(find.text('Symptoms across your cycle'), findsOneWidget);
        expect(find.byType(CorrelationChart), findsWidgets);

        // Modes — an "Open" row for the enabled mode + the on/off entry.
        expect(find.text('Modes'), findsOneWidget);
        expect(find.text('Open PCOS'), findsOneWidget);
        expect(find.text('Life-stage & condition modes'), findsOneWidget);
      },
    );
  });

  testWidgets('thin data — honest empty / keep-logging states', (tester) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await switchTab(tester, 'Patterns');

        // The cycle-stats card degrades to the keep-logging nudge.
        expect(find.text('Your cycles'), findsOneWidget);
        expect(find.textContaining('Log at least two periods'), findsOneWidget);
        expect(find.textContaining('-day typical cycle'), findsNothing);

        // BBT — the empty line, no chart.
        expect(find.text('Basal temperature'), findsOneWidget);
        expect(
          find.textContaining('Log two or more basal temperatures'),
          findsOneWidget,
        );
        expect(find.byType(BbtChart), findsNothing);

        // No fabricated correlation section, no per-mode rows.
        expect(find.text('Symptoms across your cycle'), findsNothing);
        expect(find.byType(CorrelationChart), findsNothing);
        expect(find.textContaining('Open '), findsNothing);

        // The two entries relocated from Settings are still here.
        expect(find.text('Prediction accuracy'), findsOneWidget);
        expect(find.text('Life-stage & condition modes'), findsOneWidget);
      },
    );
  });

  testWidgets('the accuracy row opens the Prediction accuracy screen', (
    tester,
  ) async {
    final db = memoryDb();
    await seedRich(db);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await switchTab(tester, 'Patterns');
        await tester.tap(find.text('Prediction accuracy'));
        // The screen replays the history behind its own spinner — flush.
        await flush(tester, 20);
        expect(
          find.widgetWithText(AppBar, 'Prediction accuracy'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('the Modes entry opens the on/off screen', (tester) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await switchTab(tester, 'Patterns');
        await tester.tap(find.text('Life-stage & condition modes'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Modes'), findsOneWidget);
      },
    );
  });

  testWidgets('an enabled mode gets an "Open" row into its screen', (
    tester,
  ) async {
    final db = memoryDb();
    await DriftSettingsRepository(
      db,
    ).set(LifeStageMode.pmdd.settingKey, 'true');

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await switchTab(tester, 'Patterns');
        final row = find.text('Open PMDD');
        expect(row, findsOneWidget);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'PMDD'), findsOneWidget);
      },
    );
  });
}
