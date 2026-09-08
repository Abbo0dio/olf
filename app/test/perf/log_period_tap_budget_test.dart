import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

/// p5.5 — the log-a-period flow stays within the §3 / §1 budget:
/// **home → a logged period in ≤ 2 taps**, with the confirmation shown inside a
/// tight feedback window. This test permanently encodes "one or two taps".
///
/// r3a re-pointed the canonical fast path (§5 negotiation, `ui-refresh.md` #r3a):
/// tap the **"Log"** FAB on Home, then **"Mark today as period start"** in the
/// day-log sheet's Flow section — a direct `addPeriod` write, no editor. It
/// still asserts a real period write via the same "Period saved." ack.
void main() {
  // §3 says < 100 ms feedback. Widget-test time is virtual; we allow a small
  // pump budget for the route pop + in-memory DB write + rebuild, and assert
  // the acknowledgement is on screen well before `pumpAndSettle` would return.
  const feedbackBudget = Duration(milliseconds: 100);
  const maxTaps = 2;

  testWidgets('home → logged period in $maxTaps taps, ack within the budget', (
    tester,
  ) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        // Start on Home with nothing logged.
        expect(find.text('Nothing logged yet.'), findsOneWidget);

        var taps = 0;

        await tester.tap(find.byType(FloatingActionButton)); // tap 1
        taps++;
        await tester.pumpAndSettle();
        expect(find.text('Mark today as period start'), findsOneWidget);

        await tester.tap(find.text('Mark today as period start')); // tap 2
        taps++;

        // Feedback budget: pump only a little, then assert the app has already
        // acknowledged — no long settle.
        await tester.pump();
        await tester.pump(feedbackBudget);

        expect(
          taps,
          lessThanOrEqualTo(maxTaps),
          reason: 'logging a period must stay within $maxTaps taps',
        );
        expect(
          find.text('Period saved.'),
          findsOneWidget,
          reason: 'the confirmation must appear within $feedbackBudget',
        );

        await tester.pumpAndSettle();
        // The write really landed: the cycle wheel now reads cycle day 1.
        expect(find.text('Day 1'), findsOneWidget);
      },
    );
  });
}
