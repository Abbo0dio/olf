import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/bbt/bbt_chart_widget.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  final today = DateTime.now();
  DateTime daysAgo(int n) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: n));

  testWidgets('the home screen shows a per-cycle BBT chart once there are '
      'two readings', (tester) async {
    final db = memoryDb();
    await DriftPeriodRepository(db).addPeriod(PeriodDraft(start: daysAgo(9)));
    final bbt = DriftBbtRepository(db);
    await bbt.setTemp(daysAgo(8), 36.4);
    await bbt.setTemp(daysAgo(5), 36.5);
    await bbt.setTemp(daysAgo(2), 36.9);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        expect(find.text('Basal temperature — this cycle'), findsOneWidget);
        expect(find.byType(BbtChart), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp(r'Basal temperature chart: 3 readings')),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('no chart with only one reading in the cycle', (tester) async {
    final db = memoryDb();
    await DriftPeriodRepository(db).addPeriod(PeriodDraft(start: daysAgo(9)));
    await DriftBbtRepository(db).setTemp(daysAgo(3), 36.6);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        expect(find.text('Basal temperature — this cycle'), findsNothing);
        expect(find.byType(BbtChart), findsNothing);
      },
    );
  });
}
