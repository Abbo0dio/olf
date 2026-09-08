import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/period/period_format.dart';
import 'package:olf_core/olf_core.dart';

import 'support/harness.dart';

/// r3a — the bottom-nav shell: Home · Calendar · Patterns in a [NavigationBar],
/// Settings as a top-right gear, the demoted Medications / Pregnancy-loss
/// screens in the Calendar tab's overflow, and a "Log" FAB on Home and
/// Calendar. The three tab bodies live in an [IndexedStack] so each keeps its
/// scroll position.
void main() {
  final today = DateTime.now();
  DateTime daysAgo(int n) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: n));

  Future<void> seedFlow(AppDatabase db, DateTime day) =>
      DriftDailyFlowRepository(
        db,
      ).setFlow(day, intensity: FlowIntensity.medium);

  testWidgets('the three tabs switch, and the AppBar title tracks them', (
    tester,
  ) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        expect(find.widgetWithText(AppBar, 'olf'), findsOneWidget);
        // Home: the slim body — a status line, no month grid, no history list.
        expect(find.text('No periods logged yet.'), findsOneWidget);
        expect(find.byTooltip('Previous month'), findsNothing);
        expect(find.text('History'), findsNothing);

        await switchTab(tester, 'Calendar');
        expect(find.widgetWithText(AppBar, 'Calendar'), findsOneWidget);
        expect(find.byTooltip('Previous month'), findsOneWidget);
        expect(find.text('History'), findsOneWidget);

        await switchTab(tester, 'Patterns');
        expect(find.widgetWithText(AppBar, 'Patterns'), findsOneWidget);
        // r3b populated this tab: section headers render even on an empty DB.
        expect(find.text('Your cycles'), findsOneWidget);
        expect(find.text('Life-stage & condition modes'), findsOneWidget);

        await switchTab(tester, 'Home');
        expect(find.widgetWithText(AppBar, 'olf'), findsOneWidget);
      },
    );
  });

  testWidgets('each tab keeps its own scroll position across a switch', (
    tester,
  ) async {
    final db = memoryDb();
    // Enough history that the Calendar list scrolls well past its viewport.
    var start = daysAgo(20 + 20 * 30);
    for (var i = 0; i < 30; i++) {
      await DriftPeriodRepository(db).addPeriod(
        PeriodDraft(start: start, end: start.add(const Duration(days: 3))),
      );
      start = start.add(const Duration(days: 20));
    }

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await switchTab(tester, 'Calendar');
        // The Calendar body's outer scroll view (its month grid nests a
        // non-scrolling GridView, hence `.first`).
        final scrollable = find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.drag(scrollable, const Offset(0, -1200));
        await tester.pumpAndSettle();
        final scrolled = tester
            .state<ScrollableState>(scrollable)
            .position
            .pixels;
        expect(scrolled, greaterThan(0));

        await switchTab(tester, 'Home');
        await switchTab(tester, 'Calendar');

        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          scrolled,
          reason: 'the Calendar tab lost its scroll offset on a tab switch',
        );
      },
    );
  });

  testWidgets('the "Log" FAB on Home opens the day-log sheet for today', (
    tester,
  ) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        expect(find.text('Day log — ${formatDay(today)}'), findsOneWidget);
      },
    );
  });

  testWidgets(
    'the "Log" FAB → "Mark today as period start" logs a period in two taps',
    (tester) async {
      final db = memoryDb();
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await tester.tap(find.byType(FloatingActionButton)); // 1
          await tester.pumpAndSettle();
          await tester.tap(find.text('Mark today as period start')); // 2
          await tester.pumpAndSettle();

          expect(find.text('Period saved.'), findsOneWidget);
          expect(find.text('Day 1'), findsOneWidget);
          expect(
            (await DriftPeriodRepository(db).allPeriods()).single.startDate,
            dateOnly(today),
          );
        },
      );
    },
  );

  testWidgets('the Calendar overflow menu reaches Medications and Pregnancy '
      'loss & birth', (tester) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await switchTab(tester, 'Calendar');

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Medications').last);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Medications'), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pregnancy loss & birth').last);
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(AppBar, 'Pregnancy loss & birth'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets(
    'Home "Recent activity" shows at most the last three logged days',
    (tester) async {
      final db = memoryDb();
      for (final ago in const [0, 1, 2, 3, 4]) {
        await seedFlow(db, daysAgo(ago));
      }

      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          expect(find.text('Recent activity'), findsOneWidget);
          expect(find.text('See all in Calendar'), findsOneWidget);
          // The three newest days are listed …
          expect(find.text(formatDay(daysAgo(0))), findsOneWidget);
          expect(find.text(formatDay(daysAgo(1))), findsOneWidget);
          expect(find.text(formatDay(daysAgo(2))), findsOneWidget);
          // … the fourth-oldest is not.
          expect(find.text(formatDay(daysAgo(3))), findsNothing);
          expect(find.text(formatDay(daysAgo(4))), findsNothing);
        },
      );
    },
  );
}
