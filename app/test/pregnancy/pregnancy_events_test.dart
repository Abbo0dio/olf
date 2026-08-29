import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  Future<void> openPage(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pregnancy loss & birth'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(AppBar, 'Pregnancy loss & birth'),
      findsOneWidget,
    );
  }

  testWidgets('record a birth, then remove it', (tester) async {
    final db = memoryDb();

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await openPage(tester);
        expect(find.text('Nothing recorded.'), findsOneWidget);

        // Add — the sheet defaults to today; switch the kind to Birth.
        await tester.tap(
          find.widgetWithText(FloatingActionButton, 'Add entry'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Birth'));
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Save entry'));
        await tester.pumpAndSettle();

        expect(find.text('Nothing recorded.'), findsNothing);
        expect(find.widgetWithText(ListTile, 'Birth'), findsOneWidget);
        final stored = await DriftCycleEventRepository(db).pregnancyEvents();
        expect(stored.single.kind, PregnancyEndKind.birth);

        // Remove it.
        await tester.tap(find.byTooltip('Remove'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Remove'));
        await tester.pumpAndSettle();

        expect(find.text('Nothing recorded.'), findsOneWidget);
        expect(await DriftCycleEventRepository(db).pregnancyEvents(), isEmpty);
      },
    );
  });
}
