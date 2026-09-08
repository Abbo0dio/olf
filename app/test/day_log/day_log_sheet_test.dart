import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/a11y/spoken_detail.dart';
import 'package:olf_app/src/cycle/cycle_wheel.dart';
import 'package:olf_app/src/period/period_format.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

/// r2 — the one unified day-log sheet (`showDayLog`) that replaced
/// `showFlowQuickLog` + `showSymptomDaySheet`. Every entry point routes to it;
/// it leads with Flow for a period day / today and Symptoms otherwise; every
/// choice upserts immediately (Flow / Symptoms / Temperature / Cervical fluid);
/// Start-a-period / Edit-dates / Manage-symptoms stay as in-sheet actions; and
/// PMDD / endometriosis quick inputs appear only when the mode is enabled.
void main() {
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  // A non-today, non-period day guaranteed inside the visible month.
  final otherDay = todayDate.day > 15
      ? DateTime(today.year, today.month, 5)
      : DateTime(today.year, today.month, 25);

  Future<void> seedPeriod(AppDatabase db, PeriodDraft draft) =>
      DriftPeriodRepository(db).addPeriod(draft);

  DateTime daysAgo(int n) => todayDate.subtract(Duration(days: n));

  Finder flowChip(String label) => find.widgetWithText(ChoiceChip, label);
  Finder symptomChip(String label) => find.widgetWithText(FilterChip, label);

  const title = 'Day log — ';

  group('every entry point opens the one sheet', () {
    testWidgets('period calendar day cell (Calendar tab)', (tester) async {
      final db = memoryDb();
      await seedPeriod(db, PeriodDraft(start: daysAgo(1), end: todayDate));
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await switchTab(tester, 'Calendar');
          await tester.tap(
            find.bySemanticsLabel('${formatDay(todayDate)}, period day'),
          );
          await tester.pumpAndSettle();
          expect(find.text('$title${formatDay(todayDate)}'), findsOneWidget);
          // period day → Flow leads (chips on screen, no expand step)
          expect(flowChip('Medium'), findsOneWidget);
          expect(symptomChip('Cramps'), findsNothing);
        },
      );
    });

    testWidgets('non-period calendar day cell → Symptoms leads', (
      tester,
    ) async {
      final db = memoryDb();
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await switchTab(tester, 'Calendar');
          await tester.tap(
            find.bySemanticsLabel('${formatDay(otherDay)}, no period logged'),
          );
          await tester.pumpAndSettle();
          expect(find.text('$title${formatDay(otherDay)}'), findsOneWidget);
          expect(symptomChip('Cramps'), findsOneWidget);
          expect(flowChip('Medium'), findsNothing);
        },
      );
    });

    testWidgets('cycle wheel → today, Flow leads', (tester) async {
      final db = memoryDb();
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await tester.tap(
            find.descendant(
              of: find.byType(CycleWheel),
              matching: find.byType(InkWell),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('$title${formatDay(todayDate)}'), findsOneWidget);
          expect(flowChip('Medium'), findsOneWidget);
        },
      );
    });

    testWidgets('home "Log" FAB → today, Flow leads', (tester) async {
      final db = memoryDb();
      await seedPeriod(db, PeriodDraft(start: daysAgo(1)));
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openDayLogForToday(tester);
          expect(find.text('$title${formatDay(todayDate)}'), findsOneWidget);
          expect(flowChip('Medium'), findsOneWidget);
          expect(symptomChip('Cramps'), findsNothing);
        },
      );
    });

    testWidgets('Calendar "Log" FAB → today, Flow leads', (tester) async {
      final db = memoryDb();
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await switchTab(tester, 'Calendar');
          await tester.tap(find.byType(FloatingActionButton));
          await tester.pumpAndSettle();
          expect(find.text('$title${formatDay(todayDate)}'), findsOneWidget);
          expect(flowChip('Medium'), findsOneWidget);
        },
      );
    });
  });

  group('immediate upsert — no Save button', () {
    testWidgets('flow: log in two taps from a period day; clots one more', (
      tester,
    ) async {
      final db = memoryDb();
      await seedPeriod(db, PeriodDraft(start: daysAgo(1), end: todayDate));
      final flow = DriftDailyFlowRepository(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          // open the sheet for today (a period day) via the "Log" FAB — the
          // Flow section leads
          await openDayLogForToday(tester);

          // clots unavailable until an intensity is picked
          expect(
            tester.widget<ChoiceChip>(flowChip('Small clots')).onSelected,
            isNull,
          );

          // tap 2: pick an intensity — this alone persists
          await tester.tap(flowChip('Medium'));
          await tester.pumpAndSettle();
          final afterIntensity = await flow.flowOn(todayDate);
          expect(afterIntensity, isNotNull);
          expect(afterIntensity!.intensity, FlowIntensity.medium);
          expect(afterIntensity.clotSize, isNull);

          // tap 3 (optional): a clot size
          await tester.tap(flowChip('Small clots'));
          await tester.pumpAndSettle();
          expect((await flow.flowOn(todayDate))!.clotSize, ClotSize.small);
        },
      );
    });

    testWidgets('flow: preselects an existing entry; Remove keeps the sheet '
        'open', (tester) async {
      final db = memoryDb();
      await seedPeriod(db, PeriodDraft(start: daysAgo(1), end: todayDate));
      final flow = DriftDailyFlowRepository(db);
      await flow.setFlow(todayDate, intensity: FlowIntensity.light);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await switchTab(tester, 'Calendar');
          await tester.tap(
            find.bySemanticsLabel(
              '${formatDay(todayDate)}, period day, flow light',
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.widget<ChoiceChip>(flowChip('Light')).selected, isTrue);

          await tester.tap(find.text('Remove'));
          await tester.pumpAndSettle();
          expect(await flow.flowOn(todayDate), isNull);
          // sheet is still open (multi-section sheet — Remove clears, not pops)
          expect(find.text('$title${formatDay(todayDate)}'), findsOneWidget);
        },
      );
    });

    testWidgets('symptoms: two taps persist; reopening preselects', (
      tester,
    ) async {
      final db = memoryDb();
      final repo = DriftSymptomRepository(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await switchTab(tester, 'Calendar');
          await tester.tap(
            find.bySemanticsLabel('${formatDay(otherDay)}, no period logged'),
          );
          await tester.pumpAndSettle();

          await tester.tap(symptomChip('Cramps'));
          await tester.pumpAndSettle();
          await tester.tap(symptomChip('Fatigue'));
          await tester.pumpAndSettle();

          final types = await repo.activeTypes();
          final cramps = types.firstWhere((t) => t.name == 'Cramps').id;
          final fatigue = types.firstWhere((t) => t.name == 'Fatigue').id;
          expect(await repo.symptomsOn(otherDay), {cramps, fatigue});

          // untick removes it
          await tester.tap(symptomChip('Cramps'));
          await tester.pumpAndSettle();
          expect(await repo.symptomsOn(otherDay), {fatigue});
        },
      );
    });

    testWidgets('cervical fluid: pick persists, shows the description line', (
      tester,
    ) async {
      final db = memoryDb();
      final mucus = DriftCervicalMucusRepository(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await switchTab(tester, 'Calendar');
          await tester.tap(
            find.bySemanticsLabel('${formatDay(otherDay)}, no period logged'),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cervical fluid'));
          await tester.pumpAndSettle();

          final type = CervicalMucusType.values.first;
          await tester.tap(find.widgetWithText(ChoiceChip, type.label));
          await tester.pumpAndSettle();
          expect(await mucus.mucusOn(otherDay), isNotNull);
          expect(find.text(type.description), findsOneWidget);
        },
      );
    });
  });

  testWidgets(
    'temperature: a passive Apple Watch reading shows distinctly and corrects '
    'into a typed basal reading (p8.1a)',
    (tester) async {
      final db = memoryDb();
      final bbt = DriftBbtRepository(db);
      await bbt.setTemp(
        todayDate,
        36.9,
        source: HealthDataSource.appleHealth,
        externalId: 'hk-wrist-1',
        measurementKind: BbtMeasurementKind.sleepingWrist,
      );
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openDayLogForToday(tester);
          await tester.tap(find.text('Temperature'));
          await tester.pumpAndSettle();

          expect(find.textContaining('Basal temp:'), findsOneWidget);
          expect(
            find.text('Apple Watch · captured while you slept'),
            findsOneWidget,
          );

          await tester.tap(find.textContaining('Basal temp:'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), '36.60');
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();

          expect(
            find.text('Apple Watch · captured while you slept'),
            findsNothing,
          );
          final row = (await bbt.tempOn(todayDate))!;
          expect(row.tempCelsius, closeTo(36.60, 1e-9));
          expect(row.measurementKind, BbtMeasurementKind.basal);
          expect(row.source, 'manual');
        },
      );
    },
  );

  group('in-sheet actions for the day state', () {
    testWidgets('non-period day offers "Start a period"', (tester) async {
      final db = memoryDb();
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await switchTab(tester, 'Calendar');
          await tester.tap(
            find.bySemanticsLabel('${formatDay(otherDay)}, no period logged'),
          );
          await tester.pumpAndSettle();
          expect(find.text('Edit period dates'), findsNothing);

          await tester.tap(find.text('Start a period'));
          await tester.pumpAndSettle();
          expect(find.text('Log a period'), findsOneWidget);
        },
      );
    });

    testWidgets('period day offers "Edit period dates"', (tester) async {
      final db = memoryDb();
      await seedPeriod(db, PeriodDraft(start: daysAgo(2), end: todayDate));
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openDayLogForToday(tester);
          expect(find.text('Start a period'), findsNothing);

          await tester.tap(find.text('Edit period dates'));
          await tester.pumpAndSettle();
          expect(find.text('Edit period'), findsOneWidget);
        },
      );
    });

    testWidgets('"Manage symptoms" is always present and reachable', (
      tester,
    ) async {
      final db = memoryDb();
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openDayLogForToday(tester);
          await tester.tap(find.text('Manage symptoms'));
          await tester.pumpAndSettle();
          expect(find.text('Add symptom'), findsOneWidget);
        },
      );
    });
  });

  group('active-mode quick-input sections', () {
    testWidgets('absent when no mode is enabled', (tester) async {
      final db = memoryDb();
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openDayLogForToday(tester);
          expect(find.text('PMDD rating'), findsNothing);
          expect(find.text('Pain & flares'), findsNothing);
        },
      );
    });

    testWidgets('PMDD section shows only when PMDD mode is on', (tester) async {
      final db = memoryDb();
      await DriftSettingsRepository(
        db,
      ).set(LifeStageMode.pmdd.settingKey, 'true');
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openDayLogForToday(tester);
          expect(find.text('PMDD rating'), findsOneWidget);
          expect(find.text('Pain & flares'), findsNothing);
        },
      );
    });

    testWidgets('endometriosis section shows only when endo mode is on', (
      tester,
    ) async {
      final db = memoryDb();
      await DriftSettingsRepository(
        db,
      ).set(LifeStageMode.endometriosis.settingKey, 'true');
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openDayLogForToday(tester);
          expect(find.text('Pain & flares'), findsOneWidget);
          expect(find.text('PMDD rating'), findsNothing);

          // reuses the existing pain-log body (its own model + Save button)
          await tester.tap(find.text('Pain & flares'));
          await tester.pumpAndSettle();
          expect(find.text('How bad is it?'), findsOneWidget);
        },
      );
    });
  });

  testWidgets('reduce spoken detail: symptom chips announce "symptom"', (
    tester,
  ) async {
    final db = memoryDb();
    final repo = DriftSymptomRepository(db);
    final headache = (await repo.activeTypes())
        .firstWhere((t) => t.name == 'Headache')
        .id;
    await repo.setSymptom(otherDay, headache, present: true);
    await pumpOlf(
      tester,
      overrides: [
        dbOverride(db),
        reduceSpokenDetailProvider.overrideWith((ref) => Stream.value(true)),
      ],
      body: () async {
        // with reduce-spoken on, the day cell itself announces only "has
        // entries" — open it and check the sheet's chips.
        await tester.tap(
          find.bySemanticsLabel('${formatDay(otherDay)}, has entries'),
        );
        await tester.pumpAndSettle();
        // visible label unchanged…
        expect(symptomChip('Headache'), findsOneWidget);
        // …screen reader hears the generic word
        expect(find.bySemanticsLabel('symptom'), findsWidgets);
        expect(find.bySemanticsLabel(RegExp(r'^Headache$')), findsNothing);
      },
    );
  });
}
