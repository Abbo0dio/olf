import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  Future<void> openPage(WidgetTester tester) async {
    // r3a/r4: reached from the Calendar tab's overflow menu, not Settings.
    await switchTab(tester, 'Calendar');
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pregnancy loss & birth').last);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(AppBar, 'Pregnancy loss & birth'),
      findsOneWidget,
    );
  }

  Future<void> addEvent(WidgetTester tester, String kindLabel) async {
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kindLabel));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save entry'));
    await tester.pumpAndSettle();
  }

  Future<bool> pregnancyModeOn(AppDatabase db) async => lifeStageModeEnabled(
    await DriftSettingsRepository(db).get(LifeStageMode.pregnancy.settingKey),
  );

  for (final (kindLabel, endKind) in const [
    ('Birth', PregnancyEndKind.birth),
    ('Pregnancy loss', PregnancyEndKind.loss),
  ]) {
    testWidgets(
      'p7.2b: a $kindLabel with pregnancy mode on turns it off and offers '
      'postpartum mode',
      (tester) async {
        final db = memoryDb();
        await DriftSettingsRepository(
          db,
        ).set(LifeStageMode.pregnancy.settingKey, 'true');

        await pumpOlf(
          tester,
          overrides: [dbOverride(db)],
          body: () async {
            await openPage(tester);
            expect(await pregnancyModeOn(db), isTrue);

            await addEvent(tester, kindLabel);

            // The p7.1 postpartum offer is shown (chain intact)…
            expect(find.text('Track your cycle coming back?'), findsOneWidget);
            await tester.tap(find.widgetWithText(TextButton, 'Not now'));
            await tester.pumpAndSettle();

            // …and pregnancy mode has been turned off (forecast card restored).
            expect(await pregnancyModeOn(db), isFalse);
            final stored = await DriftCycleEventRepository(
              db,
            ).pregnancyEvents();
            expect(stored.single.kind, endKind);
          },
        );
      },
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

        // p7.1: logging a birth offers postpartum mode — decline it here.
        await tester.tap(find.widgetWithText(TextButton, 'Not now'));
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
