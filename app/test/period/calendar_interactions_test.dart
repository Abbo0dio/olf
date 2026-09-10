import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/period/period_format.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

/// r5c — **test-only lock** on the calendar-tab month interactions that shipped
/// inside r3a: the chevron Previous/Next IconButtons, "Jump to today", and the
/// horizontal swipe month nav (GestureDetector.onHorizontalDragEnd on the month
/// grid). The r5c acceptance "swipe + chevron reach the same state" is encoded
/// here; no feature code was written and none should be needed.
///
/// The shipped behaviour under test:
/// * Prev (`_stepMonth(-1)`) always available; **Next is only wired when the
///   visible month is before the current month** (`onNext` is null today → the
///   app cannot show future months).
/// * The swipe handler reads `DragEndDetails.primaryVelocity`: negative (swipe
///   left) → next; positive (swipe right) → previous; zero → nothing.
/// * "Jump to today" (`_jumpToToday`) resets the view to this month.
void main() {
  final now = DateTime.now();
  final thisMonth = formatMonthYear(firstOfMonth(now));
  DateTime monthBy(int delta) => addMonths(firstOfMonth(now), delta);

  String labelFor(int delta) => formatMonthYear(monthBy(delta));

  Future<void> pumpCalendar(WidgetTester tester, AppDatabase db) => pumpOlf(
    tester,
    overrides: [dbOverride(db)],
    body: () async {
      await switchTab(tester, 'Calendar');
    },
  );

  final grid = find.byType(GridView);

  group('baseline', () {
    testWidgets('lands on the current month with all three controls present', (
      tester,
    ) async {
      await pumpCalendar(tester, memoryDb());
      expect(find.text(thisMonth), findsOneWidget);
      expect(find.byTooltip('Previous month'), findsOneWidget);
      expect(find.byTooltip('Jump to today'), findsOneWidget);
      // No next month in the future — the chevron is not even rendered.
      expect(find.byTooltip('Next month'), findsNothing);
    });

    testWidgets('the three controls are IconButtons with a 44px tap target', (
      tester,
    ) async {
      await pumpCalendar(tester, memoryDb());
      final prev = find.byTooltip('Previous month');
      final jump = find.byTooltip('Jump to today');
      expect(
        find.ancestor(of: prev, matching: find.byType(IconButton)),
        findsOneWidget,
      );
      expect(
        find.ancestor(of: jump, matching: find.byType(IconButton)),
        findsOneWidget,
      );
      expect(tester.getSize(prev).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(prev).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(jump).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(jump).height, greaterThanOrEqualTo(44));
    });
  });

  group('chevrons', () {
    testWidgets('Previous goes back one month; Next returns to the current', (
      tester,
    ) async {
      await pumpCalendar(tester, memoryDb());
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text(labelFor(-1)), findsOneWidget);
      expect(find.text(thisMonth), findsNothing);

      // Once on a past month, the Next chevron appears.
      expect(find.byTooltip('Next month'), findsOneWidget);
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.text(thisMonth), findsOneWidget);
      expect(find.byTooltip('Next month'), findsNothing);
    });

    testWidgets('Previous stays on the previous month under repeated taps', (
      tester,
    ) async {
      await pumpCalendar(tester, memoryDb());
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Previous month'));
        await tester.pumpAndSettle();
      }
      expect(find.text(labelFor(-3)), findsOneWidget);
    });
  });

  group('jump to today', () {
    testWidgets('restores the current month from a navigated-away month', (
      tester,
    ) async {
      await pumpCalendar(tester, memoryDb());
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Previous month'));
        await tester.pumpAndSettle();
      }
      expect(find.text(labelFor(-3)), findsOneWidget);

      await tester.tap(find.byTooltip('Jump to today'));
      await tester.pumpAndSettle();
      expect(find.text(thisMonth), findsOneWidget);
      expect(find.byTooltip('Next month'), findsNothing);
    });
  });

  group('swipe', () {
    testWidgets('swipe right (positive velocity) goes back one month', (
      tester,
    ) async {
      await pumpCalendar(tester, memoryDb());
      await tester.fling(grid, const Offset(300, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text(labelFor(-1)), findsOneWidget);
    });

    testWidgets('swipe left (negative velocity) advances one month — from a '
        'past month', (tester) async {
      await pumpCalendar(tester, memoryDb());
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text(labelFor(-1)), findsOneWidget);

      await tester.fling(grid, const Offset(-300, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text(thisMonth), findsOneWidget);
    });

    testWidgets(
      'swipe left on the current month stays put (no future months)',
      (tester) async {
        await pumpCalendar(tester, memoryDb());
        await tester.fling(grid, const Offset(-300, 0), 1500);
        await tester.pumpAndSettle();
        expect(find.text(thisMonth), findsOneWidget);
      },
    );

    testWidgets('a slow drag without a fling does not change the month', (
      tester,
    ) async {
      await pumpCalendar(tester, memoryDb());
      await tester.drag(grid, const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(find.text(thisMonth), findsOneWidget);
    });
  });

  group('swipe + chevron reach the same state', () {
    testWidgets('chevron Previous and swipe right land on the same month', (
      tester,
    ) async {
      await pumpCalendar(tester, memoryDb());

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text(labelFor(-1)), findsOneWidget);

      // Back to today, then the swipe takes the same single step.
      await tester.tap(find.byTooltip('Jump to today'));
      await tester.pumpAndSettle();
      await tester.fling(grid, const Offset(300, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text(labelFor(-1)), findsOneWidget);
      expect(find.text(thisMonth), findsNothing);
    });

    testWidgets('chevron Next and swipe left land on the same month', (
      tester,
    ) async {
      await pumpCalendar(tester, memoryDb());

      // One step back, then the chevron returns to today.
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.text(thisMonth), findsOneWidget);

      // One step back again, then the swipe returns to the same state.
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      await tester.fling(grid, const Offset(-300, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text(thisMonth), findsOneWidget);
    });
  });
}
