import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/period/period_format.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  final today = DateTime.now();

  Finder chip(String label) => find.widgetWithText(FilterChip, label);

  testWidgets(
    'log two symptoms in two taps from the calendar, and they persist',
    (tester) async {
      final db = memoryDb();
      final repo = DriftSymptomRepository(db);

      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          // tap 1: open the day sheet for today (not a period day)
          await tester.tap(
            find.bySemanticsLabel('${formatDay(today)}, no period logged'),
          );
          await tester.pumpAndSettle();
          expect(find.text('Symptoms — ${formatDay(today)}'), findsOneWidget);

          // tap 2 + 3: pick two symptoms — each persists immediately
          await tester.tap(chip('Cramps'));
          await tester.pumpAndSettle();
          await tester.tap(chip('Fatigue'));
          await tester.pumpAndSettle();

          final types = await repo.activeTypes();
          final cramps = types.firstWhere((t) => t.name == 'Cramps').id;
          final fatigue = types.firstWhere((t) => t.name == 'Fatigue').id;
          expect(await repo.symptomsOn(today), {cramps, fatigue});
        },
      );
    },
  );

  testWidgets('reopening the sheet preselects the logged symptoms', (
    tester,
  ) async {
    final db = memoryDb();
    final repo = DriftSymptomRepository(db);
    final headache = (await repo.activeTypes())
        .firstWhere((t) => t.name == 'Headache')
        .id;
    await repo.setSymptom(today, headache, present: true);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await tester.tap(
          find.bySemanticsLabel(
            '${formatDay(today)}, no period logged, 1 symptom',
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.widget<FilterChip>(chip('Headache')).selected, isTrue);
        expect(tester.widget<FilterChip>(chip('Cramps')).selected, isFalse);

        // unticking removes it
        await tester.tap(chip('Headache'));
        await tester.pumpAndSettle();
        expect(await repo.symptomsOn(today), isEmpty);
      },
    );
  });

  testWidgets('the calendar cell shows a symptom count once a day is logged', (
    tester,
  ) async {
    final db = memoryDb();
    final repo = DriftSymptomRepository(db);
    final types = await repo.activeTypes();
    await repo.setSymptom(today, types[0].id, present: true);
    await repo.setSymptom(today, types[1].id, present: true);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        expect(
          find.bySemanticsLabel(
            '${formatDay(today)}, no period logged, 2 symptoms',
          ),
          findsOneWidget,
        );
        expect(find.text("Today's symptoms: 2"), findsOneWidget);
      },
    );
  });

  testWidgets('the sheet offers "Start a period" on a non-period day', (
    tester,
  ) async {
    final db = memoryDb();

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await tester.tap(
          find.bySemanticsLabel('${formatDay(today)}, no period logged'),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Start a period'));
        await tester.pumpAndSettle();
        expect(find.text('Log a period'), findsOneWidget);
      },
    );
  });
}
