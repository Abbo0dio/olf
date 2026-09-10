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

  String labelFor(int delta) =>
      formatMonthYear(addMonths(firstOfMonth(now), delta));

  /// Run [body] — the whole assertion sequence — inside [`pumpOlf`]'s `body`:
  /// `pumpOlf` tears the app down after its body returns, so asserts must live
  /// inside it (the repo-wide pattern).
  Future<void> pumpCalendar(
    WidgetTester tester,
    AppDatabase db,
    Future<void> Function() body,
  ) => pumpOlf(
    tester,
    overrides: [dbOverride(db)],
    body: () async {
      await switchTab(tester, 'Calendar');
      await body();
    },
  );

  final grid = find.byType(GridView);

  group('baseline', () {
    testWidgets(
      'lands on the current month with all three controls present — the '
      '44px tap-target floor is the a11y sweep\'s job over this surface',
      (tester) async {
        await pumpCalendar(tester, memoryDb(), () async {
          expect(find.text(thisMonth), findsOneWidget);
          // All three affordances are reachable the way a screen reader /
          // keyboard reach them: their tooltips are their accessible names.
          expect(find.byTooltip('Previous month'), findsOneWidget);
          expect(find.byTooltip('Jump to today'), findsOneWidget);
          // Next is always rendered; on the current month it is inert (see
          // the chevrons group).
          expect(find.byTooltip('Next month'), findsOneWidget);
          // Tap-target floor (iOS 44 / Android 48) + labels + contrast are
          // asserted by the a11y guidelines over the calendar_tab surface
          // (`screen_nav.dart` — no surface added by this PR).
        });
      },
    );
  });

  group('chevrons', () {
    testWidgets('Previous goes back one month; Next returns to the current', (
      tester,
    ) async {
      await pumpCalendar(tester, memoryDb(), () async {
        await tester.tap(find.byTooltip('Previous month'));
        await tester.pumpAndSettle();
        expect(find.text(labelFor(-1)), findsOneWidget);
        expect(find.text(thisMonth), findsNothing);

        await tester.tap(find.byTooltip('Next month'));
        await tester.pumpAndSettle();
        expect(find.text(thisMonth), findsOneWidget);
      });
    });

    testWidgets('Next is inert on the current month — no future months', (
      tester,
    ) async {
      await pumpCalendar(tester, memoryDb(), () async {
        // The chevron renders, but on the current month its handler is null
        // (`onNext` is only wired once the visible month is in the past).
        expect(find.byTooltip('Next month'), findsOneWidget);
        await tester.tap(find.byTooltip('Next month'));
        await tester.pumpAndSettle();
        expect(find.text(thisMonth), findsOneWidget);
      });
    });

    testWidgets('Previous stays on the previous month under repeated taps', (
      tester,
    ) async {
      await pumpCalendar(tester, memoryDb(), () async {
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.byTooltip('Previous month'));
          await tester.pumpAndSettle();
        }
        expect(find.text(labelFor(-3)), findsOneWidget);
      });
    });
  });

  group('jump to today', () {
    testWidgets('restores the current month from a navigated-away month', (
      tester,
    ) async {
      await pumpCalendar(tester, memoryDb(), () async {
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.byTooltip('Previous month'));
          await tester.pumpAndSettle();
        }
        expect(find.text(labelFor(-3)), findsOneWidget);

        await tester.tap(find.byTooltip('Jump to today'));
        await tester.pumpAndSettle();
        expect(find.text(thisMonth), findsOneWidget);
      });
    });
  });

  group('swipe', () {
    testWidgets('swipe right (positive velocity) goes back one month', (
      tester,
    ) async {
      await pumpCalendar(tester, memoryDb(), () async {
        await tester.fling(grid, const Offset(300, 0), 1500);
        await tester.pumpAndSettle();
        expect(find.text(labelFor(-1)), findsOneWidget);
      });
    });

    testWidgets('swipe left (negative velocity) advances one month — from a '
        'past month', (tester) async {
      await pumpCalendar(tester, memoryDb(), () async {
        await tester.tap(find.byTooltip('Previous month'));
        await tester.pumpAndSettle();
        expect(find.text(labelFor(-1)), findsOneWidget);

        await tester.fling(grid, const Offset(-300, 0), 1500);
        await tester.pumpAndSettle();
        expect(find.text(thisMonth), findsOneWidget);
      });
    });

    testWidgets(
      'swipe left on the current month stays put (no future months)',
      (tester) async {
        await pumpCalendar(tester, memoryDb(), () async {
          await tester.fling(grid, const Offset(-300, 0), 1500);
          await tester.pumpAndSettle();
          expect(find.text(thisMonth), findsOneWidget);
        });
      },
    );

    testWidgets('a slow drag without a fling does not change the month', (
      tester,
    ) async {
      await pumpCalendar(tester, memoryDb(), () async {
        await tester.drag(grid, const Offset(300, 0));
        await tester.pumpAndSettle();
        expect(find.text(thisMonth), findsOneWidget);
      });
    });
  });

  group('swipe + chevron reach the same state', () {
    testWidgets('chevron Previous and swipe right land on the same month', (
      tester,
    ) async {
      await pumpCalendar(tester, memoryDb(), () async {
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
    });

    testWidgets('chevron Next and swipe left land on the same month', (
      tester,
    ) async {
      await pumpCalendar(tester, memoryDb(), () async {
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
  });
}
