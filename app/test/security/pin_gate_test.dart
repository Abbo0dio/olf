import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  // A low iteration count keeps the widget test fast; the credential carries it,
  // so verification uses the same value.
  PinCredential cred(String pin) =>
      derivePinCredential(pin, iterations: 400, random: Random(42));

  testWidgets('no PIN set → straight to the app, no lock screen', (
    tester,
  ) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        expect(find.text('Enter your PIN'), findsNothing);
        expect(find.text('No periods logged yet.'), findsOneWidget);
      },
    );
  });

  testWidgets('PIN set → lock screen gates the app until the right PIN', (
    tester,
  ) async {
    await pumpOlf(
      tester,
      pinStore: FakePinStore(cred('1379')),
      overrides: [dbOverride(memoryDb())],
      body: () async {
        expect(find.text('Enter your PIN'), findsOneWidget);
        expect(find.text('No periods logged yet.'), findsNothing);

        // Wrong PIN — stays locked, shows an error.
        await tester.enterText(find.byType(TextField), '0000');
        await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
        await flush(tester, 20);
        expect(find.textContaining('Incorrect PIN'), findsOneWidget);
        expect(find.text('No periods logged yet.'), findsNothing);

        // Right PIN — unlocks.
        await tester.enterText(find.byType(TextField), '1379');
        await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
        await flush(tester, 20);
        expect(find.text('No periods logged yet.'), findsOneWidget);
      },
    );
  });
}
