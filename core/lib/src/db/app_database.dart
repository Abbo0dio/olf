import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// The olf local database.
///
/// `core` owns the schema, the migration strategy and every query. It does
/// **not** know how the bytes are stored: the constructor takes a
/// [QueryExecutor] that the platform layer builds — an encrypted SQLCipher
/// executor in the app, a plain in-memory/temp-file one in tests.
@DriftDatabase(tables: [CycleEvents, Periods, DailyFlows])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Bump on every schema change. Each bump adds an `if (from < N)` block to
  /// [migration] `onUpgrade` **and** a migration test. See
  /// `docs/local-database.md`.
  ///
  /// v2 (p1.1): added the `periods` interval table.
  /// v3 (p1.2): added the `daily_flows` per-day table.
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // p1.1: period tracking moves from `periodStart` events to its own
        // interval table. Create it and carry every existing start over as an
        // open-ended period (no recorded end).
        await m.createTable(periods);
        await customStatement(
          'INSERT INTO periods (start_date, end_date, created_at, updated_at) '
          "SELECT date, NULL, created_at, created_at FROM cycle_events "
          "WHERE type = 'periodStart'",
        );
      }
      if (from < 3) {
        // p1.2: per-day flow logging. Purely additive — nothing to backfill.
        await m.createTable(dailyFlows);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
