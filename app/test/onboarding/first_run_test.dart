import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/onboarding/disclaimers.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  testWidgets('first run shows every required disclaimer point', (
    tester,
  ) async {
    await pumpOlf(
      tester,
      onboarded: false,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        expect(find.text(disclaimerTitle), findsOneWidget);
        for (final (heading, _) in disclaimerPoints) {
          expect(find.text(heading), findsOneWidget);
        }
        // The regulatory substance, reviewed against requirements.md §3 / §6.
        expect(find.textContaining('on this device'), findsWidgets);
        expect(find.textContaining('never sell'), findsOneWidget);
        expect(find.textContaining('HIPAA'), findsWidgets);
        expect(find.text('Not medical advice'), findsOneWidget);
        expect(find.text('Not a contraceptive'), findsOneWidget);
        // The calendar is not reachable yet.
        expect(find.text('No periods logged yet.'), findsNothing);
      },
    );
  });

  testWidgets('continue with no PIN → app is fully usable, flag persisted', (
    tester,
  ) async {
    final db = memoryDb();
    await pumpOlf(
      tester,
      onboarded: false,
      overrides: [dbOverride(db)],
      body: () async {
        await tester.tap(find.text(disclaimerAcknowledgeLabel));
        await flush(tester, 20);

        expect(find.text('No periods logged yet.'), findsOneWidget);
        expect(find.text('Add a period'), findsOneWidget);
        expect(
          await DriftSettingsRepository(db).get(SettingKeys.onboardingComplete),
          'true',
        );
      },
    );
  });

  testWidgets(
    'opting into a PIN stores a credential and still enters the app',
    (tester) async {
      final db = memoryDb();
      final pinStore = FakePinStore();

      await pumpOlf(
        tester,
        onboarded: false,
        pinStore: pinStore,
        overrides: [dbOverride(db)],
        body: () async {
          await tester.tap(find.text(disclaimerPinOptInLabel));
          await tester.pump();

          await tester.enterText(
            find.widgetWithText(TextField, 'PIN'),
            '246810',
          );
          await tester.enterText(
            find.widgetWithText(TextField, 'Confirm PIN'),
            '246810',
          );
          await tester.tap(find.text(disclaimerAcknowledgeLabel));
          await flush(tester, 30);

          // Entered the app (not the lock screen — setup counts as unlocked).
          expect(find.text('No periods logged yet.'), findsOneWidget);

          final cred = await pinStore.read();
          expect(cred, isNotNull);
          expect(verifyPin('246810', cred!), isTrue);
          expect(verifyPin('000000', cred), isFalse);
        },
      );
    },
  );

  testWidgets('mismatched PINs are rejected with a message', (tester) async {
    await pumpOlf(
      tester,
      onboarded: false,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await tester.tap(find.text(disclaimerPinOptInLabel));
        await tester.pump();
        await tester.enterText(find.widgetWithText(TextField, 'PIN'), '1234');
        await tester.enterText(
          find.widgetWithText(TextField, 'Confirm PIN'),
          '9999',
        );
        await tester.tap(find.text(disclaimerAcknowledgeLabel));
        await tester.pump();

        expect(find.textContaining("don't match"), findsOneWidget);
        expect(find.text('No periods logged yet.'), findsNothing);
      },
    );
  });
}
