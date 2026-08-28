import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// The olf local database.
///
/// `core` owns the schema, the migration strategy and every query. It does
/// **not** know how the bytes are stored: the constructor takes a
/// [QueryExecutor] that the platform layer builds — an encrypted SQLCipher
/// executor in the app, a plain in-memory/temp-file one in tests.
@DriftDatabase(tables: [CycleEvents])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Bump on every schema change. Each bump adds an `if (from < N)` block to
  /// [migration] `onUpgrade` **and** a migration test. See
  /// `docs/local-database.md`.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // No migrations yet — schemaVersion is 1. The framework is wired so the
      // first real change in Phase 1 only has to add its step here.
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
