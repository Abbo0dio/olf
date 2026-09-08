import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/period/period_format.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  final today = DateTime.now();
  DateTime daysAgo(int n) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: n));

  Future<void> seed(AppDatabase db, PeriodDraft draft) =>
      DriftPeriodRepository(db).addPeriod(draft);

  testWidgets('a seeded period shows on Home and in the Calendar history', (
    tester,
  ) async {
    final db = memoryDb();
    await seed(db, PeriodDraft(start: daysAgo(6), end: daysAgo(3)));

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        // Home: the status line under the wheel.
        expect(find.text('Last period'), findsOneWidget);
        expect(find.text(formatRange(daysAgo(6), daysAgo(3))), findsWidgets);

        // Calendar tab: the year-grouped history list.
        await switchTab(tester, 'Calendar');
        expect(find.text('History'), findsOneWidget);
        expect(find.text('${daysAgo(6).year}'), findsOneWidget);
        expect(find.text(formatRange(daysAgo(6), daysAgo(3))), findsWidgets);
      },
    );
  });

  testWidgets('the "Log" FAB → "Mark today as period start" logs a period', (
    tester,
  ) async {
    final db = memoryDb();

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mark today as period start'));
        await tester.pumpAndSettle();

        // Home status line + confirmation.
        expect(find.text('Day 1'), findsOneWidget);
        expect(find.text('Period saved.'), findsOneWidget);

        // Calendar: today's cell is a period day, and the history has a row.
        await switchTab(tester, 'Calendar');
        expect(
          find.bySemanticsLabel('${formatDay(today)}, period day'),
          findsOneWidget,
        );
        expect(find.text('History'), findsOneWidget);
        expect(find.text(formatRange(today, null)), findsWidgets);
      },
    );
  });

  testWidgets(
    'editing a period from the Calendar history keeps views in sync',
    (tester) async {
      final db = memoryDb();
      await seed(db, PeriodDraft(start: daysAgo(5), end: daysAgo(3)));

      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          expect(find.text('Last period'), findsOneWidget);

          await switchTab(tester, 'Calendar');
          // Row tap → day-log sheet → "Edit period dates" → the editor.
          await tester.tap(
            find.text(formatRange(daysAgo(5), daysAgo(3))).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Edit period dates'));
          await tester.pumpAndSettle();
          expect(find.text('Edit period'), findsOneWidget);

          // Remove the end date, making it ongoing.
          await tester.tap(find.text('This period has ended'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'Save'));
          await tester.pumpAndSettle();

          // History row now shows an open range …
          expect(find.text(formatRange(daysAgo(5), null)), findsWidgets);
          // … and Home's status line switched to the running day count.
          await switchTab(tester, 'Home');
          expect(find.text('Day 6'), findsOneWidget);
        },
      );
    },
  );

  testWidgets('deleting a period from the Calendar history clears it', (
    tester,
  ) async {
    final db = memoryDb();
    await seed(db, PeriodDraft(start: daysAgo(4), end: daysAgo(2)));

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await switchTab(tester, 'Calendar');
        await tester.tap(find.byTooltip('Delete period'));
        await tester.pumpAndSettle();
        expect(find.text('Delete this period?'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(
          find.text('Nothing logged yet. Tap a day or the Log button.'),
          findsOneWidget,
        );
        await switchTab(tester, 'Home');
        expect(find.text('No periods logged yet.'), findsOneWidget);
      },
    );
  });

  testWidgets('tapping a period day on the Calendar opens the day-log sheet; '
      '"Edit period dates" reaches the period editor', (tester) async {
    final db = memoryDb();
    await seed(db, PeriodDraft(start: daysAgo(2), end: today));

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await switchTab(tester, 'Calendar');
        await tester.tap(
          find.bySemanticsLabel('${formatDay(today)}, period day'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Day log — ${formatDay(today)}'), findsOneWidget);

        await tester.tap(find.text('Edit period dates'));
        await tester.pumpAndSettle();
        expect(find.text('Edit period'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      },
    );
  });
}
