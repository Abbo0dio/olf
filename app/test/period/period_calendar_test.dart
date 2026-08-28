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

  testWidgets('a seeded period shows in the summary and the history list', (
    tester,
  ) async {
    final db = memoryDb();
    await seed(db, PeriodDraft(start: daysAgo(6), end: daysAgo(3)));

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        expect(find.text('Last period'), findsOneWidget);
        expect(
          find.text(formatRange(daysAgo(6), daysAgo(3))),
          findsWidgets, // summary + history row
        );
        expect(find.text('History'), findsOneWidget);
      },
    );
  });

  testWidgets('adding a period updates the calendar, summary and history', (
    tester,
  ) async {
    final db = memoryDb();

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await tester.tap(find.text('Add a period'));
        await tester.pumpAndSettle();
        expect(find.text('Log a period'), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();

        // summary
        expect(find.text('Day 1'), findsOneWidget);
        // calendar cell for today is now a period day
        expect(
          find.bySemanticsLabel('${formatDay(today)}, period day'),
          findsOneWidget,
        );
        // history
        expect(find.text('History'), findsOneWidget);
        expect(find.text(formatRange(today, null)), findsWidgets);
        expect(find.text('Period saved.'), findsOneWidget);
      },
    );
  });

  testWidgets('editing a period from history keeps every view in sync', (
    tester,
  ) async {
    final db = memoryDb();
    await seed(db, PeriodDraft(start: daysAgo(5), end: daysAgo(3)));

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        // before: a closed 3-day period
        expect(find.text('Last period'), findsOneWidget);

        await tester.tap(find.byTooltip('Edit period'));
        await tester.pumpAndSettle();
        expect(find.text('Edit period'), findsOneWidget);

        // remove the end date, making it ongoing
        await tester.tap(find.text('This period has ended'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();

        // summary switched to the running "Day N", history shows an open range
        expect(find.text('Day 6'), findsOneWidget);
        expect(find.text(formatRange(daysAgo(5), null)), findsWidgets);
      },
    );
  });

  testWidgets('deleting a period from history clears it everywhere', (
    tester,
  ) async {
    final db = memoryDb();
    await seed(db, PeriodDraft(start: daysAgo(4), end: daysAgo(2)));

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await tester.tap(find.byTooltip('Delete period'));
        await tester.pumpAndSettle();
        expect(find.text('Delete this period?'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(find.text('No periods logged yet.'), findsOneWidget);
        expect(
          find.text('Nothing logged yet. Tap a day or "Add a period".'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('tapping a period day on the calendar opens its editor', (
    tester,
  ) async {
    final db = memoryDb();
    await seed(db, PeriodDraft(start: daysAgo(2), end: today));

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await tester.tap(
          find.bySemanticsLabel('${formatDay(today)}, period day'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Edit period'), findsOneWidget);
        // delete is reachable straight from the calendar, not only from history
        expect(find.text('Delete'), findsOneWidget);

        // close the sheet
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      },
    );
  });
}
