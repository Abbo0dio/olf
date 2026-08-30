import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/security/biometric_gateway.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  // Low iterations keep the credential hash fast; it carries the count so
  // verification uses the same value.
  PinCredential cred(String pin) =>
      derivePinCredential(pin, iterations: 400, random: Random(1));

  Future<void> enableBiometricSetting(AppDatabase db) =>
      DriftSettingsRepository(db).set(SettingKeys.biometricUnlock, 'true');

  testWidgets('opted in + capable → the prompt fires on open and unlocks', (
    tester,
  ) async {
    final db = memoryDb();
    await enableBiometricSetting(db);
    final gateway = FakeBiometricGateway(capable: true);

    await pumpOlf(
      tester,
      pinStore: FakePinStore(cred('1379')),
      biometricGateway: gateway,
      overrides: [dbOverride(db)],
      body: () async {
        await flush(tester, 20);
        // Never had to type the PIN.
        expect(gateway.prompts, greaterThanOrEqualTo(1));
        expect(find.text('Enter your PIN'), findsNothing);
        expect(find.text('No periods logged yet.'), findsOneWidget);
      },
    );
  });

  testWidgets('biometric fails → stays locked, the PIN still unlocks', (
    tester,
  ) async {
    final db = memoryDb();
    await enableBiometricSetting(db);
    final gateway = FakeBiometricGateway(
      capable: true,
      result: BiometricAuthResult.failed,
    );

    await pumpOlf(
      tester,
      pinStore: FakePinStore(cred('1379')),
      biometricGateway: gateway,
      overrides: [dbOverride(db)],
      body: () async {
        await flush(tester, 20);
        expect(gateway.prompts, greaterThanOrEqualTo(1));
        expect(find.text('Enter your PIN'), findsOneWidget);

        await tester.enterText(find.byType(TextField), '1379');
        await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
        await flush(tester, 20);
        expect(find.text('No periods logged yet.'), findsOneWidget);
      },
    );
  });

  testWidgets('the "Use biometrics" button retries the prompt', (tester) async {
    final db = memoryDb();
    await enableBiometricSetting(db);
    final gateway = FakeBiometricGateway(
      capable: true,
      result: BiometricAuthResult.failed,
    );

    await pumpOlf(
      tester,
      pinStore: FakePinStore(cred('1379')),
      biometricGateway: gateway,
      overrides: [dbOverride(db)],
      body: () async {
        await flush(tester, 20);
        expect(find.text('Enter your PIN'), findsOneWidget);

        gateway.result = BiometricAuthResult.success;
        await tester.tap(find.text('Use biometrics'));
        await flush(tester, 20);
        expect(find.text('No periods logged yet.'), findsOneWidget);
      },
    );
  });

  testWidgets('device not capable → no prompt, no button, PIN unchanged', (
    tester,
  ) async {
    final db = memoryDb();
    await enableBiometricSetting(db);
    final gateway = FakeBiometricGateway(capable: false);

    await pumpOlf(
      tester,
      pinStore: FakePinStore(cred('1379')),
      biometricGateway: gateway,
      overrides: [dbOverride(db)],
      body: () async {
        await flush(tester, 20);
        expect(gateway.prompts, 0);
        expect(find.text('Use biometrics'), findsNothing);
        expect(find.text('Enter your PIN'), findsOneWidget);

        await tester.enterText(find.byType(TextField), '1379');
        await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
        await flush(tester, 20);
        expect(find.text('No periods logged yet.'), findsOneWidget);
      },
    );
  });
}
