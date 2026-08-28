// On-device integration test for the p0.4 slice, run in CI by the **nightly**
// workflow (.github/workflows/nightly-integration.yml) on an Android emulator
// and an iOS simulator. Not part of the PR-blocking `CI` workflow.
//
//   flutter test integration_test/log_period_test.dart      # needs a device
//
// It exercises the real path: SQLCipher (sqlcipher_flutter_libs) + the platform
// key store (flutter_secure_storage). The headless equivalents that DO run on
// every PR are core/test/db/persistence_test.dart and app/test/widget_test.dart.

import 'package:flutter/widgets.dart';
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

  Future<bool> isClosed(AppDatabase db) async {
    try {
      await db.customSelect('SELECT 1').get();
      return false;
    } catch (_) {
      return true;
    }
  }

  testWidgets(
    'log -> relaunch (DB closed then reopened from disk) -> persists -> remove',
    (tester) async {
      final logButton = find.text('Period started today');
      final dayReadout = find.textContaining('Day ');
      final removeButton = find.text('Remove this entry');
      final emptyState = find.text('Nothing logged yet.');

      // --- launch 1: log today ---
      final c1 = ProviderContainer();
      await launch(
        tester,
        c1,
        () =>
            logButton.evaluate().isNotEmpty || dayReadout.evaluate().isNotEmpty,
      );

      if (logButton.evaluate().isNotEmpty) {
        await tester.tap(logButton);
        await tester.pump(const Duration(seconds: 1));
      }
      expect(dayReadout, findsOneWidget);

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
      expect(
        identical(db1, db2),
        isFalse,
        reason: 'launch 2 must build a new database instance',
      );
      expect(
        dayReadout,
        findsOneWidget,
      ); // the logged entry survived the reopen

      // --- leave state clean for the next nightly run ---
      await tester.tap(removeButton);
      await tester.pump(const Duration(seconds: 1));
      expect(emptyState, findsOneWidget);
    },
  );
}
