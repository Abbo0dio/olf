import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/period/period_format.dart';
import 'package:olf_app/src/providers.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  // These tests deliberately hold a real and a decoy AppDatabase around a vault
  // switch; that is the design, not the footgun the warning is about.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  PinCredential cred(String pin) =>
      derivePinCredential(pin, iterations: 200, random: Random(1));

  final today = DateTime.now();
  DateTime daysAgo(int n) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: n));

  /// A real vault with one logged period; a fresh copy on each open so a test
  /// can re-open it after a vault switch.
  Future<AppDatabase> seededReal() async {
    final db = AppDatabase(NativeDatabase.memory());
    await DriftPeriodRepository(
      db,
    ).addPeriod(PeriodDraft(start: daysAgo(6), end: daysAgo(3)));
    return db;
  }

  Future<AppDatabase> emptyDecoy() async =>
      AppDatabase(NativeDatabase.memory());

  FakeVaultOpener vaultOpener() {
    final opener = FakeVaultOpener(real: seededReal, decoy: emptyDecoy);
    addTearDown(opener.closeAll);
    return opener;
  }

  testWidgets(
    'the decoy PIN opens an empty vault with no sign of the real data',
    (tester) async {
      final opener = vaultOpener();

      await pumpOlf(
        tester,
        pinStore: FakePinStore(cred('1379')),
        decoyPinStore: FakePinStore(cred('2468')),
        overrides: [vaultDatabaseOpenerProvider.overrideWithValue(opener)],
        body: () async {
          expect(find.text('Enter your PIN'), findsOneWidget);

          await tester.enterText(find.byType(TextField), '2468');
          await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
          await flush(tester, 25);

          // Decoy vault: empty, and the seeded real period is nowhere.
          expect(find.text('No periods logged yet.'), findsOneWidget);
          expect(find.text('Last period'), findsNothing);
          expect(find.text(formatRange(daysAgo(6), daysAgo(3))), findsNothing);

          // Settings gives no hint a decoy exists.
          await tester.tap(find.byTooltip('Settings'));
          await tester.pumpAndSettle();
          expect(find.textContaining('Decoy'), findsNothing);
          expect(find.textContaining('decoy'), findsNothing);
          // The normal app-lock row is still there (managing the decoy PIN).
          expect(
            find.widgetWithText(SwitchListTile, 'App lock (PIN)'),
            findsOneWidget,
          );
        },
      );
    },
  );

  testWidgets('the real PIN still opens the real vault with its data', (
    tester,
  ) async {
    final opener = vaultOpener();

    await pumpOlf(
      tester,
      pinStore: FakePinStore(cred('1379')),
      decoyPinStore: FakePinStore(cred('2468')),
      overrides: [vaultDatabaseOpenerProvider.overrideWithValue(opener)],
      body: () async {
        await tester.enterText(find.byType(TextField), '1379');
        await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
        await flush(tester, 25);

        expect(find.text('Last period'), findsOneWidget);
        expect(find.text('History'), findsOneWidget);
        expect(find.text('No periods logged yet.'), findsNothing);
      },
    );
  });

  testWidgets('backgrounding a decoy session forces the real PIN next time', (
    tester,
  ) async {
    final opener = vaultOpener();

    await pumpOlf(
      tester,
      pinStore: FakePinStore(cred('1379')),
      decoyPinStore: FakePinStore(cred('2468')),
      overrides: [vaultDatabaseOpenerProvider.overrideWithValue(opener)],
      body: () async {
        await tester.enterText(find.byType(TextField), '2468');
        await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
        await flush(tester, 25);
        expect(find.text('No periods logged yet.'), findsOneWidget);

        // Background, then foreground.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await flush(tester, 25);

        // Locked again — and it is the real lock screen now.
        expect(find.text('Enter your PIN'), findsOneWidget);

        await tester.enterText(find.byType(TextField), '1379');
        await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
        await flush(tester, 25);
        expect(find.text('Last period'), findsOneWidget);
      },
    );
  });

  testWidgets('a decoy PIN equal to the real PIN is refused', (tester) async {
    final decoyStore = FakePinStore();

    await pumpOlf(
      tester,
      pinStore: FakePinStore(cred('4682')),
      decoyPinStore: decoyStore,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await tester.enterText(find.byType(TextField), '4682');
        await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
        await flush(tester, 20);

        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(SwitchListTile, 'Decoy PIN'));
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextField, 'PIN'), '4682');
        await tester.enterText(
          find.widgetWithText(TextField, 'Confirm PIN'),
          '4682',
        );
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await flush(tester, 20);

        expect(
          find.text('Choose a code different from your main PIN.'),
          findsOneWidget,
        );
        expect(await decoyStore.read(), isNull);
        expect(find.text('Change decoy PIN'), findsNothing);

        // A different code is accepted.
        await tester.tap(find.widgetWithText(SwitchListTile, 'Decoy PIN'));
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextField, 'PIN'), '1357');
        await tester.enterText(
          find.widgetWithText(TextField, 'Confirm PIN'),
          '1357',
        );
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await flush(tester, 20);

        expect(await decoyStore.read(), isNotNull);
        expect(find.text('Change decoy PIN'), findsOneWidget);
      },
    );
  });
}
