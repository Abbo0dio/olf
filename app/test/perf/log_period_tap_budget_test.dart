import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

/// p5.5 — the log-a-period flow stays within the §3 / §1 budget:
/// **home → a logged period in ≤ 2 taps**, with the confirmation shown inside a
/// tight feedback window. This test permanently encodes "one or two taps".
///
/// The canonical fast path (see `period_calendar_test.dart`): tap **"Add a
/// period"** on the calendar, then **"Save"** in the editor, which is pre-filled
/// with today — no date entry needed.
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
        // Start on the calendar with nothing logged.
        expect(find.text('Add a period'), findsOneWidget);
        expect(
          find.text('Nothing logged yet. Tap a day or "Add a period".'),
          findsOneWidget,
        );

        var taps = 0;

        await tester.tap(find.text('Add a period'));
        taps++;
        await tester.pumpAndSettle();
        expect(find.text('Log a period'), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
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
        expect(find.text('Day 1'), findsOneWidget);

        await tester.pumpAndSettle();
      },
    );
  });
}
