import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  }

  testWidgets('turn the app lock on from settings → a PIN is stored', (
    tester,
  ) async {
    final pinStore = FakePinStore();

    await pumpOlf(
      tester,
      pinStore: pinStore,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await openSettings(tester);

        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();

        await tester.enterText(find.widgetWithText(TextField, 'PIN'), '4682');
        await tester.enterText(
          find.widgetWithText(TextField, 'Confirm PIN'),
          '4682',
        );
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await flush(tester, 20);

        expect(await pinStore.read(), isNotNull);
        expect(find.text('Change PIN'), findsOneWidget);
      },
    );
  });

  testWidgets('turn the app lock off → the PIN is cleared', (tester) async {
    // Low iterations keep the test quick; the credential carries the count.
    final pinStore = FakePinStore(
      derivePinCredential('4682', iterations: 400, random: Random(1)),
    );

    await pumpOlf(
      tester,
      pinStore: pinStore,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        // A seeded PIN means the lock screen is up first — get past it.
        await tester.enterText(find.byType(TextField), '4682');
        await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
        await flush(tester, 20);

        await openSettings(tester);
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Turn off'));
        await flush(tester, 20);

        expect(await pinStore.read(), isNull);
      },
    );
  });

  testWidgets('pick Dark in Appearance → persisted and MaterialApp follows', (
    tester,
  ) async {
    final db = memoryDb();
    final settings = DriftSettingsRepository(db);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await openSettings(tester);
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
          ThemeMode.system,
        );

        await tester.tap(find.text('Dark'));
        await tester.pumpAndSettle();

        expect(await settings.get(SettingKeys.themeMode), 'dark');
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
          ThemeMode.dark,
        );
      },
    );
  });

  testWidgets(
    'pick she / her in Pronouns → persisted and the preview updates',
    (tester) async {
      final db = memoryDb();
      final settings = DriftSettingsRepository(db);

      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openSettings(tester);
          expect(
            find.text(pronounExampleSentence(Pronouns.unspecified)),
            findsOneWidget,
          );

          await tester.tap(
            find.widgetWithText(
              RadioListTile<Pronouns>,
              describePronouns(Pronouns.sheHer),
            ),
          );
          await tester.pumpAndSettle();

          expect(await settings.get(SettingKeys.pronouns), 'sheHer');
          expect(
            find.text(pronounExampleSentence(Pronouns.sheHer)),
            findsOneWidget,
          );
        },
      );
    },
  );
}
