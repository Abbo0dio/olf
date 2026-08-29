import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/period/period_format.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  final today = DateTime.now();
  DateTime daysAgo(int n) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: n));

  Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

  testWidgets(
    'pick a cervical-fluid quality → it persists and can be cleared',
    (tester) async {
      final db = memoryDb();
      final repo = DriftCervicalMucusRepository(db);

      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await tester.tap(
            find.bySemanticsLabel('${formatDay(today)}, no period logged'),
          );
          await tester.pumpAndSettle();

          await tester.tap(chip('Creamy'));
          await tester.pumpAndSettle();
          expect(await repo.mucusOn(today), isNotNull);
          expect((await repo.mucusOn(today))!.type, CervicalMucusType.creamy);

          // tapping the selected chip again clears the day
          await tester.tap(chip('Creamy'));
          await tester.pumpAndSettle();
          expect(await repo.mucusOn(today), isNull);
        },
      );
    },
  );

  testWidgets('a fertile-quality observation feeds the prediction card', (
    tester,
  ) async {
    final db = memoryDb();
    final periods = DriftPeriodRepository(db);
    // two closed periods → one completed cycle → the prediction card renders,
    // and today is not itself a period day (so its cell opens the day sheet)
    await periods.addPeriod(PeriodDraft(start: daysAgo(40), end: daysAgo(37)));
    await periods.addPeriod(PeriodDraft(start: daysAgo(12), end: daysAgo(9)));

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        expect(find.text('Fertile window (estimate)'), findsOneWidget);
        expect(
          find.textContaining('Fertile signs (from your notes)'),
          findsNothing,
        );

        // log egg-white today (inside the current cycle)
        await tester.tap(
          find.bySemanticsLabel('${formatDay(today)}, no period logged'),
        );
        await tester.pumpAndSettle();
        await tester.tap(chip('Egg-white'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Done'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Fertile signs (from your notes)'),
          findsOneWidget,
        );
      },
    );
  });
}
