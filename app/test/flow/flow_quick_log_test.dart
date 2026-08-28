import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/period/period_format.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  final today = DateTime.now();
  DateTime daysAgo(int n) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: n));

  Future<void> seedPeriod(AppDatabase db, PeriodDraft draft) =>
      DriftPeriodRepository(db).addPeriod(draft);

  Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

  testWidgets(
    'log flow in two taps from the calendar; clots are one tap more',
    (tester) async {
      final db = memoryDb();
      await seedPeriod(db, PeriodDraft(start: daysAgo(1), end: today));
      final flow = DriftDailyFlowRepository(db);

      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          // tap 1: open the quick-log for today
          await tester.tap(
            find.bySemanticsLabel('${formatDay(today)}, period day'),
          );
          await tester.pumpAndSettle();
          expect(find.text('Flow — ${formatDay(today)}'), findsOneWidget);

          // clots are unavailable until an intensity is picked
          expect(
            tester.widget<ChoiceChip>(chip('Small clots')).onSelected,
            isNull,
          );

          // tap 2: pick an intensity — this alone persists the entry
          await tester.tap(chip('Medium'));
          await tester.pumpAndSettle();
          final afterIntensity = await flow.flowOn(today);
          expect(afterIntensity, isNotNull);
          expect(afterIntensity!.intensity, FlowIntensity.medium);
          expect(afterIntensity.clotSize, isNull);

          // tap 3 (optional): add a clot size
          await tester.tap(chip('Small clots'));
          await tester.pumpAndSettle();
          expect((await flow.flowOn(today))!.clotSize, ClotSize.small);
        },
      );
    },
  );

  testWidgets('a logged day renders its value on the calendar cell', (
    tester,
  ) async {
    final db = memoryDb();
    // Ongoing period (no end) so the summary's "Today's flow" chip renders.
    await seedPeriod(db, PeriodDraft(start: daysAgo(1)));
    await DriftDailyFlowRepository(
      db,
    ).setFlow(today, intensity: FlowIntensity.heavy, clotSize: ClotSize.large);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        expect(
          find.bySemanticsLabel(
            '${formatDay(today)}, period day, flow heavy with large clots',
          ),
          findsOneWidget,
        );
        // and the summary chip reflects it
        expect(find.text("Today's flow: Heavy"), findsOneWidget);
      },
    );
  });

  testWidgets('the quick-log preselects an existing entry and can remove it', (
    tester,
  ) async {
    final db = memoryDb();
    await seedPeriod(db, PeriodDraft(start: daysAgo(1), end: today));
    final flow = DriftDailyFlowRepository(db);
    await flow.setFlow(today, intensity: FlowIntensity.light);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await tester.tap(
          find.bySemanticsLabel('${formatDay(today)}, period day, flow light'),
        );
        await tester.pumpAndSettle();

        expect(tester.widget<ChoiceChip>(chip('Light')).selected, isTrue);

        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();
        expect(await flow.flowOn(today), isNull);
      },
    );
  });
}
