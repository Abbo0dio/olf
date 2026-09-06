import 'dart:io';

import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// Schema v9 → v10 (p8.1a): `bbt_entries` gains `measurement_kind TEXT NOT NULL
/// DEFAULT 'basal'` — the discriminator that keeps a passive Apple Watch
/// sleeping-wrist import out of the basal-body-temperature readers while still
/// letting it reconcile for the one-row-per-day slot.
///
/// The second ALTER of an existing table in olf's history (after v7's
/// `source` / `external_id`). Column-level changes can't be reconstructed by
/// the historical-snapshot tool, so this hand-rolled per-feature check mirrors
/// `fertility_migration_test.dart`: a real on-disk v9 file with a couple of
/// existing `bbt_entries` rows, opened through [AppDatabase] so
/// `migration.onUpgrade` runs. The exhaustive v(old)→v10 matrix (including the
/// backup round-trip carrying a `sleepingWrist` row) lives in
/// `migration_matrix_test.dart`; see `docs/local-database.md`.
void main() {
  late Directory tmp;
  late File dbFile;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('olf_wrist_temp_migration_test');
    dbFile = File('${tmp.path}/olf.db');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  int unixSeconds(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  /// Write [dbFile] at exactly the v9 shape (v7 provenance columns + the p7.5
  /// `pain_entries` and p7.6 `pmdd_ratings` tables) with two existing
  /// `bbt_entries` rows — one plain, one already carrying an `external_id` from
  /// a p6.2 `basalBodyTemperature` import — then close it.
  void createV9Database() {
    final raw = sqlite3.open(dbFile.path);
    raw.execute('''
      CREATE TABLE "cycle_events" (
        "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "type" TEXT NOT NULL,
        "date" INTEGER NOT NULL,
        "created_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
      CREATE TABLE "periods" (
        "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "start_date" INTEGER NOT NULL,
        "end_date" INTEGER,
        "created_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        "updated_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
      CREATE TABLE "daily_flows" (
        "date" INTEGER NOT NULL PRIMARY KEY,
        "intensity" TEXT NOT NULL,
        "clot_size" TEXT,
        "source" TEXT NOT NULL DEFAULT 'manual',
        "external_id" TEXT,
        "created_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        "updated_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
      CREATE TABLE "symptom_types" (
        "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "name" TEXT NOT NULL,
        "sort_order" INTEGER NOT NULL,
        "is_built_in" INTEGER NOT NULL DEFAULT 0,
        "archived_at" INTEGER,
        "created_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        "updated_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
      CREATE TABLE "daily_symptom_entries" (
        "date" INTEGER NOT NULL,
        "symptom_type_id" INTEGER NOT NULL,
        "created_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        PRIMARY KEY ("date", "symptom_type_id"),
        FOREIGN KEY (symptom_type_id) REFERENCES symptom_types (id) ON DELETE CASCADE
      );
      CREATE TABLE "bbt_entries" (
        "date" INTEGER NOT NULL PRIMARY KEY,
        "temp_celsius" REAL NOT NULL,
        "source" TEXT NOT NULL DEFAULT 'manual',
        "external_id" TEXT,
        "created_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        "updated_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
      CREATE TABLE "cervical_mucus_entries" (
        "date" INTEGER NOT NULL PRIMARY KEY,
        "type" TEXT NOT NULL,
        "created_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        "updated_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
      CREATE TABLE "app_settings" (
        "key" TEXT NOT NULL PRIMARY KEY,
        "value" TEXT NOT NULL,
        "updated_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
      CREATE TABLE "medications" (
        "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "name" TEXT NOT NULL,
        "dosage" TEXT,
        "notes" TEXT,
        "archived_at" INTEGER,
        "created_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        "updated_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
      CREATE TABLE "birth_control_entries" (
        "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "method" TEXT NOT NULL,
        "started_on" INTEGER NOT NULL,
        "ended_on" INTEGER,
        "notes" TEXT,
        "created_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        "updated_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
      CREATE TABLE "reminders" (
        "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "kind" TEXT NOT NULL,
        "hour" INTEGER NOT NULL,
        "minute" INTEGER NOT NULL,
        "enabled" INTEGER NOT NULL DEFAULT 0,
        "created_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        "updated_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        UNIQUE ("kind")
      );
      CREATE TABLE "pain_entries" (
        "date" INTEGER NOT NULL PRIMARY KEY,
        "intensity" TEXT NOT NULL,
        "region" TEXT,
        "note" TEXT,
        "is_flare" INTEGER NOT NULL DEFAULT 0,
        "created_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        "updated_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
      CREATE TABLE "pmdd_ratings" (
        "date" INTEGER NOT NULL,
        "item" TEXT NOT NULL,
        "rating" TEXT NOT NULL,
        "created_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        "updated_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
        PRIMARY KEY ("date", "item")
      );
    ''');
    // A plain user-typed reading, and one imported from a health platform.
    raw.execute(
      'INSERT INTO bbt_entries (date, temp_celsius, source, external_id, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [unixSeconds(DateTime(2026, 7, 10)), 36.51, 'manual', null, 0, 0],
    );
    raw.execute(
      'INSERT INTO bbt_entries (date, temp_celsius, source, external_id, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [
        unixSeconds(DateTime(2026, 7, 11)),
        36.72,
        'appleHealth',
        'hk-basal-1',
        0,
        0,
      ],
    );
    raw.execute('PRAGMA user_version = 9;');
    raw.dispose();
  }

  test(
    'opening a v9 database upgrades to v10, adding bbt_entries.measurement_kind',
    () async {
      createV9Database();

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.first, db.schemaVersion);
      expect(db.schemaVersion, 10);

      // The new column exists: TEXT, NOT NULL, not part of the PK, default 'basal'.
      final columns = await db
          .customSelect("PRAGMA table_info('bbt_entries')")
          .get();
      final byName = {
        for (final row in columns)
          row.data['name'] as String: (
            (row.data['type'] as String).toUpperCase(),
            (row.data['notnull'] as int) == 1,
            (row.data['pk'] as int),
            row.data['dflt_value'],
          ),
      };
      expect(
        byName.keys,
        containsAll(<String>{
          'date',
          'temp_celsius',
          'source',
          'external_id',
          'measurement_kind',
          'created_at',
          'updated_at',
        }),
      );
      final kind = byName['measurement_kind']!;
      expect(kind.$1, 'TEXT');
      expect(kind.$2, isTrue); // NOT NULL
      expect(kind.$3, 0); // not in the primary key
      expect(
        kind.$4.toString().replaceAll("'", ''),
        'basal',
      ); // DEFAULT 'basal'

      // Integrity is clean and every pre-existing row comes out as a basal
      // reading — the migration changes no behaviour for existing data.
      final integrity = await db
          .customSelect('PRAGMA integrity_check')
          .getSingle();
      expect(integrity.data.values.first, 'ok');

      final repoForRead = DriftBbtRepository(db);
      final migrated = await repoForRead.allEntries(); // newest day first
      expect(migrated, hasLength(2));
      expect(
        migrated.every((r) => r.measurementKind == BbtMeasurementKind.basal),
        isTrue,
      );
      final byDay = {for (final r in migrated) r.date: r};
      expect(byDay[DateTime(2026, 7, 10)]!.tempCelsius, 36.51);
      expect(byDay[DateTime(2026, 7, 10)]!.source, 'manual');
      expect(byDay[DateTime(2026, 7, 11)]!.source, 'appleHealth');
      expect(byDay[DateTime(2026, 7, 11)]!.externalId, 'hk-basal-1');

      // The migrated table is usable through the real repository: a passive
      // Apple Watch reading stores as `sleepingWrist`, and correcting it in-app
      // (no kind passed) resets the row to `basal`.
      final repo = DriftBbtRepository(db, now: () => DateTime(2026, 7, 12));
      await repo.setTemp(
        DateTime(2026, 7, 12),
        36.95,
        source: HealthDataSource.appleHealth,
        externalId: 'hk-wrist-1',
        measurementKind: BbtMeasurementKind.sleepingWrist,
      );
      var wrist = await repo.tempOn(DateTime(2026, 7, 12));
      expect(wrist!.measurementKind, BbtMeasurementKind.sleepingWrist);
      expect(wrist.source, 'appleHealth');

      await repo.setTemp(DateTime(2026, 7, 12), 36.60);
      wrist = await repo.tempOn(DateTime(2026, 7, 12));
      expect(wrist!.measurementKind, BbtMeasurementKind.basal);
      expect(wrist.source, 'manual');
      expect(wrist.externalId, 'hk-wrist-1'); // externalId stays sticky
    },
  );
}
