import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// The olf local database.
///
/// `core` owns the schema, the migration strategy and every query. It does
/// **not** know how the bytes are stored: the constructor takes a
/// [QueryExecutor] that the platform layer builds — an encrypted SQLCipher
/// executor in the app, a plain in-memory/temp-file one in tests.
@DriftDatabase(
  tables: [
    CycleEvents,
    Periods,
    DailyFlows,
    SymptomTypes,
    DailySymptomEntries,
    BbtEntries,
    CervicalMucusEntries,
    AppSettings,
    Medications,
    BirthControlEntries,
    Reminders,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Bump on every schema change. Each bump adds an `if (from < N)` block to
  /// [migration] `onUpgrade` **and** a migration test. See
  /// `docs/local-database.md`.
  ///
  /// v2 (p1.1): added the `periods` interval table.
  /// v3 (p1.2): added the `daily_flows` per-day table.
  /// v4 (p1.5): added the `symptom_types` catalogue + `daily_symptom_entries`,
  ///            and seeded the built-in symptom names.
  /// v5 (p1.6): added `bbt_entries`, `cervical_mucus_entries` and the
  ///            `app_settings` key/value store.
  /// v6 (p1.7): added `medications`, `birth_control_entries` and the
  ///            `reminders` table (one daily local reminder).
  /// v7 (p6.1): added `source` + `external_id` provenance columns to
  ///            `bbt_entries` and `daily_flows` for health-platform interop.
  ///            **First migration that alters an existing table** — see
  ///            `tool/dump_historical_schemas.dart` for why v6 is the snapshot
  ///            reconstruction anchor.
  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedBuiltInSymptoms();
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
      if (from < 4) {
        // p1.5: symptom catalogue + per-day entries. Additive; the catalogue is
        // seeded with the built-in names so an upgraded database looks the same
        // as a fresh one.
        await m.createTable(symptomTypes);
        await m.createTable(dailySymptomEntries);
        await _seedBuiltInSymptoms();
      }
      if (from < 5) {
        // p1.6: manual BBT, cervical-mucus observations, and a key/value prefs
        // store. Purely additive — nothing to backfill.
        await m.createTable(bbtEntries);
        await m.createTable(cervicalMucusEntries);
        await m.createTable(appSettings);
      }
      if (from < 6) {
        // p1.7: medication list, birth-control method history, and the single
        // daily reminder. Purely additive — nothing to backfill.
        await m.createTable(medications);
        await m.createTable(birthControlEntries);
        await m.createTable(reminders);
      }
      if (from < 7 && to >= 7) {
        // p6.1: health-platform provenance — `source` + `external_id` on
        // `daily_flows` and `bbt_entries`. First migration to ALTER an existing
        // table. `source` defaults to 'manual' so every row already in the
        // database is marked user-entered; `external_id` stays NULL until a
        // sample is round-tripped through a HealthPlatformGateway.
        //
        // The `to >= 7` guard exists because this is the first *column* change:
        // the single-step `migration_matrix_test` migrates to intermediate
        // targets, and running this block for `to < 7` would leave the pre-v7
        // snapshots' `daily_flows` / `bbt_entries` carrying columns they should
        // not have. (The earlier createTable-only blocks don't need it — an
        // extra *table* is tolerated by the schema verifier; extra *columns* on
        // a checked table are not.)
        //
        // Only ALTER a table that an *earlier* migration already created in its
        // pre-v7 shape: when `from` predates a table's own version, the
        // `createTable` above builds it with these columns already present, so a
        // second `addColumn` would be a duplicate. `daily_flows` arrived in v3,
        // `bbt_entries` in v5.
        if (from >= 3) {
          await m.addColumn(dailyFlows, dailyFlows.source);
          await m.addColumn(dailyFlows, dailyFlows.externalId);
        }
        if (from >= 5) {
          await m.addColumn(bbtEntries, bbtEntries.source);
          await m.addColumn(bbtEntries, bbtEntries.externalId);
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Insert [kBuiltInSymptomNames] as active, `isBuiltIn` catalogue rows with
  /// ascending `sortOrder`. Called from both `onCreate` and the v3 → v4 upgrade.
  Future<void> _seedBuiltInSymptoms() async {
    await batch((b) {
      for (var i = 0; i < kBuiltInSymptomNames.length; i++) {
        b.insert(
          symptomTypes,
          SymptomTypesCompanion.insert(
            name: kBuiltInSymptomNames[i],
            sortOrder: i,
            isBuiltIn: const Value(true),
          ),
        );
      }
    });
  }
}
