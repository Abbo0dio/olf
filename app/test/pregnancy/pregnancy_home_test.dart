import 'package:flutter_test/flutter_test.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  DateTime daysAgo(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: n));
  }

  testWidgets(
    'a recorded birth pauses the forecast and shows the postpartum note',
    (tester) async {
      final db = memoryDb();
      final periods = DriftPeriodRepository(db);
      // A history that would normally produce a confident forecast…
      await periods.addPeriod(
        PeriodDraft(start: daysAgo(120), end: daysAgo(116)),
      );
      await periods.addPeriod(
        PeriodDraft(start: daysAgo(92), end: daysAgo(88)),
      );
      await periods.addPeriod(
        PeriodDraft(start: daysAgo(64), end: daysAgo(60)),
      );
      // …but a birth sits in the still-open cycle.
      await DriftCycleEventRepository(
        db,
      ).logPregnancyEnd(PregnancyEndKind.birth, daysAgo(20));

      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          expect(find.textContaining('recorded a birth'), findsOneWidget);
          expect(
            find.textContaining('paused period estimates'),
            findsOneWidget,
          );
          // No forecast card across the event.
          expect(find.textContaining('Next period'), findsNothing);
        },
      );
    },
  );

  testWidgets('the note clears once a period is logged after the birth', (
    tester,
  ) async {
    final db = memoryDb();
    final periods = DriftPeriodRepository(db);
    await periods.addPeriod(
      PeriodDraft(start: daysAgo(120), end: daysAgo(116)),
    );
    await DriftCycleEventRepository(
      db,
    ).logPregnancyEnd(PregnancyEndKind.birth, daysAgo(40));
    await periods.addPeriod(PeriodDraft(start: daysAgo(8), end: daysAgo(4)));

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        expect(find.textContaining('recorded a birth'), findsNothing);
      },
    );
  });
}
