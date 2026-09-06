import 'dart:io';

import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// Schema v8 → v9 (p7.6): the `pmdd_ratings` per-`(date, item)` table is added.
/// Purely additive — nothing is backfilled, and existing rows must be untouched.
///
/// Hand-rolled like `pain_migration_test.dart`: a real on-disk v8 file is built,
/// then opened through [AppDatabase] so `migration.onUpgrade` runs. The
/// exhaustive v(old)→v9 matrix lives in `migration_matrix_test.dart`; this is
/// the focused per-feature check kept for context (see `docs/local-database.md`).
void main() {
  late Directory tmp;
  late File dbFile;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('olf_pmdd_migration_test');
    dbFile = File('${tmp.path}/olf.db');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  int unixSeconds(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  /// Write [dbFile] at exactly the v8 shape (v7 tables + the p7.5 `pain_entries`
  /// table), with a couple of existing rows, then close it.
  void createV8Database(DateTime periodStart, DateTime periodEnd) {
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
      'INSERT INTO pain_entries (date, intensity, region, note, is_flare, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [unixSeconds(periodStart), 'moderate', 'pelvic', 'existing row', 1, 0, 0],
    );
    raw.execute('PRAGMA user_version = 8;');
    raw.dispose();
  }

  test('opening a v8 database upgrades to v9, adding pmdd_ratings', () async {
    createV8Database(DateTime(2026, 7, 10), DateTime(2026, 7, 14));

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, db.schemaVersion);
    expect(db.schemaVersion, 11);

    // New table exists with the expected shape: composite (date, item) PK.
    final columns = await db
        .customSelect("PRAGMA table_info('pmdd_ratings')")
        .get();
    final byName = {
      for (final row in columns)
        row.data['name'] as String: (
          (row.data['type'] as String).toUpperCase(),
          (row.data['notnull'] as int) == 1,
          (row.data['pk'] as int),
        ),
    };
    expect(
      byName.keys,
      containsAll(<String>{
        'date',
        'item',
        'rating',
        'created_at',
        'updated_at',
      }),
    );
    expect(byName['date'], ('INTEGER', true, 1)); // pk part 1
    expect(byName['item'], ('TEXT', true, 2)); // pk part 2
    expect(byName['rating'], ('TEXT', true, 0));

    // Integrity is clean and the existing rows are untouched.
    final integrity = await db
        .customSelect('PRAGMA integrity_check')
        .getSingle();
    expect(integrity.data.values.first, 'ok');

    final period = (await DriftPeriodRepository(db).allPeriods()).single;
    expect(period.startDate, DateTime(2026, 7, 10));
    expect(period.endDate, DateTime(2026, 7, 14));
    final pain = (await DriftPainRepository(db).allEntries()).single;
    expect(pain.intensity, SymptomSeverity.moderate);
    expect(pain.note, 'existing row');

    // And the new table is usable through the real repository — round-tripping
    // several items per day, including an explicit `none` rating.
    final repo = DriftPmddRatingRepository(
      db,
      now: () => DateTime(2026, 7, 12),
    );
    await repo.rateDay(DateTime(2026, 7, 12), {
      PmddSymptom.irritability: SymptomSeverity.severe,
      PmddSymptom.lowMood: SymptomSeverity.moderate,
      PmddSymptom.bloating: SymptomSeverity.none,
    });
    final ratings = await repo.ratingsOn(DateTime(2026, 7, 12));
    expect(ratings[PmddSymptom.irritability], SymptomSeverity.severe);
    expect(ratings[PmddSymptom.lowMood], SymptomSeverity.moderate);
    expect(ratings[PmddSymptom.bloating], SymptomSeverity.none);

    await repo.clearDay(DateTime(2026, 7, 12));
    expect(await repo.ratingsOn(DateTime(2026, 7, 12)), isEmpty);
  });
}
