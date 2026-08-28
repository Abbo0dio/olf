// On-device integration test for the p1.1 slice (period logging), run in CI by
// the **nightly** workflow (.github/workflows/nightly-integration.yml) on an
// Android emulator and an iOS simulator. Not part of the PR-blocking `CI`
// workflow.
//
//   flutter test integration_test/log_period_test.dart      # needs a device
//
// It exercises the real path: SQLCipher (sqlcipher_flutter_libs) + the platform
// key store (flutter_secure_storage). The headless equivalents that DO run on
// every PR are core/test/db/period_migration_test.dart,
// core/test/db/persistence_test.dart and app/test/period/*.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:olf_app/main.dart';
import 'package:olf_app/src/providers.dart';
import 'package:olf_core/olf_core.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Pump [OlfApp] under [container] and wait (bounded — never `pumpAndSettle`,
  /// which would hang on the loading spinner) until [ready] is true.
  Future<void> launch(
    WidgetTester tester,
    ProviderContainer container,
    bool Function() ready,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const OlfApp()),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (ready()) return;
    }
    fail('timed out waiting for home content to render');
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<bool> isClosed(AppDatabase db) async {
    try {
      await db.customSelect('SELECT 1').get();
      return false;
    } catch (_) {
      return true;
    }
  }

  testWidgets('add -> relaunch (DB closed then reopened) -> edit -> delete', (
    tester,
  ) async {
    final addButton = find.text('Add a period');
    final saveButton = find.widgetWithText(FilledButton, 'Save');
    final dayReadout = find.textContaining('Day ');
    final editButton = find.byTooltip('Edit period');
    final deleteButton = find.byTooltip('Delete period');
    final emptyState = find.text('No periods logged yet.');
    final endedToggle = find.text('This period has ended');

    // --- launch 1: add a period for today ---
    final c1 = ProviderContainer();
    await launch(tester, c1, () => addButton.evaluate().isNotEmpty);

    await tapVisible(tester, addButton);
    expect(find.text('Log a period'), findsOneWidget);
    await tapVisible(tester, saveButton);
    expect(dayReadout, findsOneWidget); // summary now reads "Day 1"

    final db1 = c1.read(appDatabaseProvider).requireValue;

    // --- relaunch: tear launch 1 down; its onDispose closes the database ---
    await tester.pumpWidget(const SizedBox());
    c1.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(
      await isClosed(db1),
      isTrue,
      reason: 'the pre-relaunch database must actually be closed',
    );

    // --- launch 2: a fresh container reopens the SAME encrypted file ---
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    await launch(tester, c2, () => dayReadout.evaluate().isNotEmpty);

    final db2 = c2.read(appDatabaseProvider).requireValue;
    expect(identical(db1, db2), isFalse);
    expect(dayReadout, findsOneWidget); // the entry survived the reopen

    // --- edit it from the history list ---
    await tapVisible(tester, editButton);
    expect(find.text('Edit period'), findsOneWidget);
    await tapVisible(tester, endedToggle); // give it an end date
    await tapVisible(tester, saveButton);
    expect(find.text('Period saved.'), findsOneWidget);

    // --- delete it, leaving state clean for the next nightly run ---
    await tapVisible(tester, deleteButton);
    await tapVisible(tester, find.widgetWithText(TextButton, 'Delete'));
    expect(emptyState, findsOneWidget);
  });
}
