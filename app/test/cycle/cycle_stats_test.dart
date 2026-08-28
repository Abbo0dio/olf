import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  final today = DateTime.now();
  DateTime daysAgo(int n) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: n));

  Future<void> seed(AppDatabase db, PeriodDraft draft) =>
      DriftPeriodRepository(db).addPeriod(draft);

  testWidgets('two regular cycles surface a typical length and variability', (
    tester,
  ) async {
    final db = memoryDb();
    // 4-day bleeds, each period 28 days after the previous.
    await seed(db, PeriodDraft(start: daysAgo(60), end: daysAgo(57)));
    await seed(db, PeriodDraft(start: daysAgo(32), end: daysAgo(29)));
    await seed(db, PeriodDraft(start: daysAgo(4), end: daysAgo(1)));

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        expect(find.text('28-day typical cycle'), findsOneWidget);
        expect(find.text('Regular'), findsOneWidget);
        expect(find.text('Typical period 4 days'), findsOneWidget);
        // history rows carry the derived cycle length
        expect(find.text('28-day cycle'), findsNWidgets(2));
        expect(find.text('Current cycle'), findsOneWidget);
      },
    );
  });

  testWidgets('a single logged period shows a keep-logging nudge, no crash', (
    tester,
  ) async {
    final db = memoryDb();
    await seed(db, PeriodDraft(start: daysAgo(6), end: daysAgo(3)));

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        expect(find.textContaining('Log at least two periods'), findsOneWidget);
        expect(find.textContaining('28-day'), findsNothing);
        expect(find.text('History'), findsOneWidget);
      },
    );
  });

  testWidgets('the card recomputes when a period is removed', (tester) async {
    final db = memoryDb();
    await seed(db, PeriodDraft(start: daysAgo(34), end: daysAgo(31)));
    await seed(db, PeriodDraft(start: daysAgo(6), end: daysAgo(3)));

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        expect(find.text('28-day typical cycle'), findsOneWidget);

        await tester.tap(find.byTooltip('Delete period').first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();

        // one period left → back to the nudge, no stale "28-day" figure
        expect(find.text('28-day typical cycle'), findsNothing);
        expect(find.textContaining('Log at least two periods'), findsOneWidget);
      },
    );
  });

  testWidgets('a long gap is flagged rather than treated as one cycle', (
    tester,
  ) async {
    final db = memoryDb();
    await seed(db, PeriodDraft(start: daysAgo(90), end: daysAgo(87)));
    await seed(db, PeriodDraft(start: daysAgo(30), end: daysAgo(27))); // +60
    await seed(db, PeriodDraft(start: daysAgo(2))); // +28, ongoing

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        // the 28-day cycle still counts; the 60-day stretch does not
        expect(find.text('28-day typical cycle'), findsOneWidget);
        expect(
          find.textContaining('a period may not have been logged'),
          findsWidgets,
        );
      },
    );
  });
}
