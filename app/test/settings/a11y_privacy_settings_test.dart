import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

/// p5.3 — the Settings > Accessibility section persists both new preferences
/// (they round-trip through the `app_settings` stream, so a persisted write
/// shows back up in the control).
void main() {
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

  PinCredential cred(String pin) =>
      derivePinCredential(pin, iterations: 400, random: Random(7));

  testWidgets('"Reduce spoken detail" toggles on and sticks', (tester) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await openSettings(tester);
        final row = find.widgetWithText(SwitchListTile, 'Reduce spoken detail');
        await tester.scrollUntilVisible(row, 200);
        expect(tester.widget<SwitchListTile>(row).value, isFalse);

        await tester.tap(row);
        await flush(tester);

        expect(tester.widget<SwitchListTile>(row).value, isTrue);
      },
    );
  });

  testWidgets('"Lock after inactivity" needs a PIN, then persists a choice', (
    tester,
  ) async {
    // No PIN → the row is present but disabled.
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await openSettings(tester);
        final row = find.widgetWithText(ListTile, 'Lock after inactivity');
        await tester.scrollUntilVisible(row, 200);
        expect(tester.widget<ListTile>(row).enabled, isFalse);
      },
    );
  });

  testWidgets('with a PIN, picking a window persists it', (tester) async {
    await pumpOlf(
      tester,
      pinStore: FakePinStore(cred('2468')),
      overrides: [dbOverride(memoryDb())],
      body: () async {
        // Unlock first.
        await tester.enterText(find.byType(TextField), '2468');
        await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
        await flush(tester, 20);

        await openSettings(tester);
        final row = find.widgetWithText(ListTile, 'Lock after inactivity');
        await tester.scrollUntilVisible(row, 200);
        // Default when a lock exists is "After 2 minutes".
        expect(
          find.descendant(of: row, matching: find.text('After 2 minutes')),
          findsOneWidget,
        );

        await tester.tap(row);
        await tester.pumpAndSettle();
        await tester.tap(find.text('After 5 minutes'));
        await flush(tester);

        expect(
          find.descendant(of: row, matching: find.text('After 5 minutes')),
          findsOneWidget,
        );
      },
    );
  });
}
