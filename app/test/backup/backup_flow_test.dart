import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/backup/backup_providers.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';
import 'fake_backup_gateway.dart';

void main() {
  // The real PBKDF2 work factor runs here (no test seam for it — it is a
  // security parameter), so wait on the result rather than `pumpAndSettle`
  // (the page shows a spinner while it works).
  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 50));
      if (finder.evaluate().isNotEmpty) return;
    }
    throw StateError('timed out waiting for $finder');
  }

  Future<void> openBackupPage(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backup & restore'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Backup & restore'), findsOneWidget);
  }

  Future<void> enterInDialog(
    WidgetTester tester,
    String label,
    String text,
  ) async {
    await tester.enterText(find.widgetWithText(TextField, label), text);
    await tester.pump();
  }

  testWidgets('export then restore round-trips through the UI', (tester) async {
    final db = memoryDb();
    final gateway = FakeBackupGateway();
    await DriftPeriodRepository(
      db,
    ).addPeriod(PeriodDraft(start: DateTime.utc(2026, 4, 1)));
    final seeded = (await db.select(db.periods).get()).single;

    await pumpOlf(
      tester,
      overrides: [
        dbOverride(db),
        backupFileGatewayProvider.overrideWithValue(gateway),
      ],
      body: () async {
        await openBackupPage(tester);

        // --- Export ---
        await tester.tap(find.text('Create an encrypted backup'));
        await tester.pumpAndSettle();
        await enterInDialog(tester, 'Passphrase', 'correct-horse');
        await enterInDialog(tester, 'Confirm passphrase', 'correct-horse');
        await tester.tap(find.widgetWithText(TextButton, 'OK'));
        await pumpUntil(tester, find.text('Backup saved.'));
        expect(gateway.file, isNotNull);

        // Lose the data.
        await db.customStatement('DELETE FROM periods');
        expect(await db.select(db.periods).get(), isEmpty);

        // --- Restore ---
        await tester.tap(find.text('Restore from a backup file'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Choose file'));
        await tester.pumpAndSettle();
        await enterInDialog(tester, 'Passphrase', 'correct-horse');
        await tester.tap(find.widgetWithText(TextButton, 'OK'));
        await pumpUntil(tester, find.textContaining('Restored'));

        // Restoring pops back to the home screen.
        expect(find.widgetWithText(AppBar, 'Backup & restore'), findsNothing);

        final periods = await db.select(db.periods).get();
        expect(periods, hasLength(1));
        // Exact round trip — same id and same stored instant as before export.
        expect(periods.single.id, seeded.id);
        expect(periods.single.startDate, seeded.startDate);
        expect(periods.single.endDate, seeded.endDate);
      },
    );
  });

  testWidgets('a wrong passphrase on restore is reported, data untouched', (
    tester,
  ) async {
    final db = memoryDb();
    final gateway = FakeBackupGateway();
    await DriftPeriodRepository(
      db,
    ).addPeriod(PeriodDraft(start: DateTime.utc(2026, 4, 1)));

    await pumpOlf(
      tester,
      overrides: [
        dbOverride(db),
        backupFileGatewayProvider.overrideWithValue(gateway),
      ],
      body: () async {
        await openBackupPage(tester);

        await tester.tap(find.text('Create an encrypted backup'));
        await tester.pumpAndSettle();
        await enterInDialog(tester, 'Passphrase', 'the-right-one');
        await enterInDialog(tester, 'Confirm passphrase', 'the-right-one');
        await tester.tap(find.widgetWithText(TextButton, 'OK'));
        await pumpUntil(tester, find.text('Backup saved.'));

        await tester.tap(find.text('Restore from a backup file'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Choose file'));
        await tester.pumpAndSettle();
        await enterInDialog(tester, 'Passphrase', 'the-wrong-one');
        await tester.tap(find.widgetWithText(TextButton, 'OK'));
        await pumpUntil(
          tester,
          find.text('That passphrase did not match the file.'),
        );

        expect(await db.select(db.periods).get(), hasLength(1));
      },
    );
  });
}
