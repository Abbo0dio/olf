import 'dart:io';

import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// Schema v10 → v11 (p8.2): **both** `daily_flows` and `bbt_entries` gain
/// `source_device TEXT` (nullable, no default) — the free-form device / app tag
/// for a health-platform import, so olf can label a reading "from your Oura
/// Ring". Provenance only; every pre-existing row comes out `NULL`.
///
/// The third ALTER of an existing table in olf's history (after v7's
/// `source` / `external_id` and v10's `measurement_kind`), and the first to
/// touch two tables in one step. Column-level changes can't be reconstructed by
/// the historical-snapshot tool, so this hand-rolled per-feature check mirrors
/// `wrist_temp_migration_test.dart`: a real on-disk v10 file with a couple of
/// existing rows in each table, opened through [AppDatabase] so
/// `migration.onUpgrade` runs. The exhaustive v(old)→v11 matrix (including the
/// backup round-trip carrying a non-null `source_device` row) lives in
/// `migration_matrix_test.dart`; see `docs/local-database.md`.
void main() {
  late Directory tmp;
  late File dbFile;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync(
      'olf_source_device_migration_test',
    );
    dbFile = File('${tmp.path}/olf.db');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  int unixSeconds(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  /// Write [dbFile] at exactly the v10 shape (v7 provenance columns on both
  /// per-day tables + v10's `bbt_entries.measurement_kind` + the p7.5
  /// `pain_entries` and p7.6 `pmdd_ratings` tables) with two existing
  /// `daily_flows` rows and two existing `bbt_entries` rows — one plain, one
  /// already carrying an `external_id` from a p6.2 import — then close it.
  void createV10Database() {
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
        "measurement_kind" TEXT NOT NULL DEFAULT 'basal',
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
    // Two flow days: one user-typed, one imported.
    raw.execute(
      'INSERT INTO daily_flows (date, intensity, source, external_id, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [unixSeconds(DateTime(2026, 7, 10)), 'medium', 'manual', null, 0, 0],
    );
    raw.execute(
      'INSERT INTO daily_flows (date, intensity, source, external_id, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [
        unixSeconds(DateTime(2026, 7, 11)),
        'light',
        'healthConnect',
        'hc-flow-1',
        0,
        0,
      ],
    );
    // Two BBT readings: one user-typed, one imported.
    raw.execute(
      'INSERT INTO bbt_entries (date, temp_celsius, measurement_kind, source, external_id, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        unixSeconds(DateTime(2026, 7, 10)),
        36.51,
        'basal',
        'manual',
        null,
        0,
        0,
      ],
    );
    raw.execute(
      'INSERT INTO bbt_entries (date, temp_celsius, measurement_kind, source, external_id, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        unixSeconds(DateTime(2026, 7, 11)),
        36.72,
        'basal',
        'appleHealth',
        'hk-basal-1',
        0,
        0,
      ],
    );
    raw.execute('PRAGMA user_version = 10;');
    raw.dispose();
  }

  test('opening a v10 database upgrades to v11, adding source_device to '
      'daily_flows AND bbt_entries', () async {
    createV10Database();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, db.schemaVersion);
    expect(db.schemaVersion, 11);

    // The new column exists on both tables: TEXT, nullable, not part of the
    // PK, no default.
    for (final table in const ['daily_flows', 'bbt_entries']) {
      final columns = await db
          .customSelect("PRAGMA table_info('$table')")
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
        contains('source_device'),
        reason: '$table is missing source_device',
      );
      final col = byName['source_device']!;
      expect(col.$1, 'TEXT', reason: '$table.source_device type');
      expect(col.$2, isFalse, reason: '$table.source_device must be nullable');
      expect(col.$3, 0, reason: '$table.source_device must not be in the PK');
      expect(
        col.$4,
        isNull,
        reason: '$table.source_device must have no default',
      );
    }

    final integrity = await db
        .customSelect('PRAGMA integrity_check')
        .getSingle();
    expect(integrity.data.values.first, 'ok');

    // Every pre-existing row comes out with source_device NULL — the
    // migration changes no behaviour for existing data.
    final flowRepo = DriftDailyFlowRepository(db);
    final flows = await flowRepo.allFlows();
    expect(flows, hasLength(2));
    expect(flows.every((r) => r.sourceDevice == null), isTrue);

    final bbtRepo = DriftBbtRepository(db);
    final bbts = await bbtRepo.allEntries();
    expect(bbts, hasLength(2));
    expect(bbts.every((r) => r.sourceDevice == null), isTrue);

    // The migrated tables are usable through the real repositories: an import
    // stamps a device tag, and correcting the row in-app (no tag passed)
    // clears it.
    final flowWrite = DriftDailyFlowRepository(
      db,
      now: () => DateTime(2026, 7, 12),
    );
    await flowWrite.setFlow(
      DateTime(2026, 7, 12),
      intensity: FlowIntensity.light,
      source: HealthDataSource.healthConnect,
      externalId: 'hc-flow-2',
      sourceDevice: 'com.ouraring.oura',
    );
    var flow = await flowWrite.flowOn(DateTime(2026, 7, 12));
    expect(flow!.sourceDevice, 'com.ouraring.oura');
    await flowWrite.setFlow(
      DateTime(2026, 7, 12),
      intensity: FlowIntensity.medium,
    );
    flow = await flowWrite.flowOn(DateTime(2026, 7, 12));
    expect(flow!.sourceDevice, isNull);
    expect(flow.source, 'manual');
    expect(flow.externalId, 'hc-flow-2'); // externalId stays sticky

    final bbtWrite = DriftBbtRepository(db, now: () => DateTime(2026, 7, 12));
    await bbtWrite.setTemp(
      DateTime(2026, 7, 12),
      36.90,
      source: HealthDataSource.appleHealth,
      externalId: 'hk-basal-2',
      sourceDevice: 'Oura',
    );
    var bbt = await bbtWrite.tempOn(DateTime(2026, 7, 12));
    expect(bbt!.sourceDevice, 'Oura');
    await bbtWrite.setTemp(DateTime(2026, 7, 12), 36.60);
    bbt = await bbtWrite.tempOn(DateTime(2026, 7, 12));
    expect(bbt!.sourceDevice, isNull);
    expect(bbt.source, 'manual');
    expect(bbt.externalId, 'hk-basal-2'); // externalId stays sticky
  });
}
