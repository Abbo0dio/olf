import 'dart:io';

import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// Schema v7 → v8 (p7.5): the `pain_entries` per-day table is added. Purely
/// additive — nothing is backfilled, and existing rows must be untouched.
///
/// Hand-rolled like `flow_migration_test.dart` / `meds_migration_test.dart`: a
/// real on-disk v7 file is built, then opened through [AppDatabase] so
/// `migration.onUpgrade` runs. The exhaustive v(old)→v8 matrix lives in
/// `migration_matrix_test.dart`; this is the focused per-feature check kept for
/// context (see `docs/local-database.md`).
void main() {
  late Directory tmp;
  late File dbFile;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('olf_pain_migration_test');
    dbFile = File('${tmp.path}/olf.db');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  int unixSeconds(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  /// Write [dbFile] at exactly the v7 shape (v6 tables + the p6.1 `source` /
  /// `external_id` provenance columns on `daily_flows` and `bbt_entries`), with
  /// a couple of existing rows, then close it.
  void createV7Database(DateTime periodStart, DateTime periodEnd) {
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
    ''');
    raw.execute(
      'INSERT INTO periods (start_date, end_date, created_at, updated_at) '
      'VALUES (?, ?, ?, ?)',
      [
        unixSeconds(periodStart),
        unixSeconds(periodEnd),
        unixSeconds(periodStart),
        unixSeconds(periodStart),
      ],
    );
    raw.execute(
      'INSERT INTO daily_flows (date, intensity, clot_size, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?)',
      [unixSeconds(periodStart), 'heavy', null, 0, 0],
    );
    raw.execute('PRAGMA user_version = 7;');
    raw.dispose();
  }

  test('opening a v7 database upgrades to v8, adding pain_entries', () async {
    createV7Database(DateTime(2026, 7, 10), DateTime(2026, 7, 14));

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, db.schemaVersion);
    expect(db.schemaVersion, 11);

    // New table exists with the expected shape.
    final columns = await db
        .customSelect("PRAGMA table_info('pain_entries')")
        .get();
    final byName = {
      for (final row in columns)
        row.data['name'] as String: (
          (row.data['type'] as String).toUpperCase(),
          (row.data['notnull'] as int) == 1,
          (row.data['pk'] as int) != 0,
        ),
    };
    expect(
      byName.keys,
      containsAll(<String>{
        'date',
        'intensity',
        'region',
        'note',
        'is_flare',
        'created_at',
        'updated_at',
      }),
    );
    expect(byName['date'], ('INTEGER', true, true)); // primary key
    expect(byName['intensity'], ('TEXT', true, false));
    expect(byName['region'], ('TEXT', false, false)); // nullable
    expect(byName['note'], ('TEXT', false, false)); // nullable

    // Integrity is clean and the existing rows are untouched.
    final integrity = await db
        .customSelect('PRAGMA integrity_check')
        .getSingle();
    expect(integrity.data.values.first, 'ok');

    final period = (await DriftPeriodRepository(db).allPeriods()).single;
    expect(period.startDate, DateTime(2026, 7, 10));
    expect(period.endDate, DateTime(2026, 7, 14));
    expect(
      (await DriftDailyFlowRepository(db).allFlows()).single.intensity,
      FlowIntensity.heavy,
    );

    // And the new table is usable through the real repository, round-tripping
    // the ordered scale, the region enum, the free-text note and the flare flag.
    final pain = DriftPainRepository(db, now: () => DateTime(2026, 7, 12));
    await pain.setPain(
      DateTime(2026, 7, 12),
      intensity: SymptomSeverity.severe,
      region: PainRegion.lowerBack,
      note: 'kept me up',
      isFlare: true,
    );
    final entry = (await pain.painOn(DateTime(2026, 7, 12)))!;
    expect(entry.intensity, SymptomSeverity.severe);
    expect(entry.region, PainRegion.lowerBack);
    expect(entry.note, 'kept me up');
    expect(entry.isFlare, isTrue);

    await pain.clearDay(DateTime(2026, 7, 12));
    expect(await pain.painOn(DateTime(2026, 7, 12)), isNull);
  });
}
