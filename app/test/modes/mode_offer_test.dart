import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  Future<void> logBirth(WidgetTester tester) async {
    // r3a/r4: "Pregnancy loss & birth" is in the Calendar tab's overflow menu.
    await switchTab(tester, 'Calendar');
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pregnancy loss & birth').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Birth'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save entry'));
    await tester.pumpAndSettle();
  }

  testWidgets('logging a birth offers postpartum mode — dismissible, opt-in', (
    tester,
  ) async {
    final db = memoryDb();
    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await logBirth(tester);

        // The offer is shown…
        expect(find.text('Track your cycle coming back?'), findsOneWidget);

        // …and declining it leaves the mode off.
        await tester.tap(find.widgetWithText(TextButton, 'Not now'));
        await tester.pumpAndSettle();
        expect(find.text('Track your cycle coming back?'), findsNothing);

        final stored = await DriftSettingsRepository(
          db,
        ).get(LifeStageMode.postpartum.settingKey);
        expect(lifeStageModeEnabled(stored), isFalse);
      },
    );
  });

  testWidgets('the mode turns on only when the user accepts the offer', (
    tester,
  ) async {
    final db = memoryDb();
    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await logBirth(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Turn it on'));
        await tester.pumpAndSettle();

        final stored = await DriftSettingsRepository(
          db,
        ).get(LifeStageMode.postpartum.settingKey);
        expect(lifeStageModeEnabled(stored), isTrue);
        expect(find.text('Postpartum mode is on.'), findsOneWidget);
      },
    );
  });
}
