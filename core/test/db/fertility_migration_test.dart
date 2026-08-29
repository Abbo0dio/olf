import 'dart:io';

import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// Schema v4 → v5 (p1.6): adds `bbt_entries`, `cervical_mucus_entries` and the
/// `app_settings` key/value store. Purely additive — existing rows are untouched.
///
/// Hand-rolled like the earlier migration tests: a real on-disk v4 file is
/// built, then opened through [AppDatabase] so `migration.onUpgrade` runs.
void main() {
  late Directory tmp;
  late File dbFile;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('olf_fertility_migration_test');
    dbFile = File('${tmp.path}/olf.db');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  int unixSeconds(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  /// Write [dbFile] at exactly the v4 shape with one period, one flow row and
  /// one symptom entry, then close it.
  void createV4Database(DateTime periodStart, DateTime periodEnd) {
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
      'INSERT INTO daily_flows (date, intensity, created_at, updated_at) '
      'VALUES (?, ?, ?, ?)',
      [
        unixSeconds(DateTime(2026, 7, 12)),
        'heavy',
        unixSeconds(periodStart),
        unixSeconds(periodStart),
      ],
    );
    raw.execute(
      'INSERT INTO symptom_types (name, sort_order, is_built_in) '
      'VALUES (?, ?, ?)',
      ['Cramps', 0, 1],
    );
    raw.execute(
      'INSERT INTO daily_symptom_entries (date, symptom_type_id, created_at) '
      'VALUES (?, ?, ?)',
      [unixSeconds(DateTime(2026, 7, 12)), 1, unixSeconds(periodStart)],
    );
    raw.execute('PRAGMA user_version = 4;');
    raw.dispose();
  }

  test(
    'opening a v4 database upgrades it to v5 and adds the new tables',
    () async {
      createV4Database(DateTime(2026, 7, 10), DateTime(2026, 7, 14));

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.first, db.schemaVersion);
      expect(db.schemaVersion, 5);

      final newTables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name IN "
            "('bbt_entries', 'cervical_mucus_entries', 'app_settings')",
          )
          .get();
      expect(newTables.map((r) => r.data['name'] as String).toSet(), {
        'bbt_entries',
        'cervical_mucus_entries',
        'app_settings',
      });

      // Existing rows survived untouched.
      final period = (await DriftPeriodRepository(db).allPeriods()).single;
      expect(period.startDate, DateTime(2026, 7, 10));
      expect(
        (await DriftDailyFlowRepository(
          db,
        ).flowOn(DateTime(2026, 7, 12)))!.intensity,
        FlowIntensity.heavy,
      );
      expect(
        await DriftSymptomRepository(db).symptomsOn(DateTime(2026, 7, 12)),
        {1},
      );

      // The new tables are usable.
      final bbt = DriftBbtRepository(db, now: () => DateTime(2026, 7, 12));
      await bbt.setTemp(DateTime(2026, 7, 12), 36.6);
      expect((await bbt.tempOn(DateTime(2026, 7, 12)))!.tempCelsius, 36.6);

      final mucus = DriftCervicalMucusRepository(db);
      await mucus.setMucus(DateTime(2026, 7, 12), CervicalMucusType.eggWhite);
      expect(
        (await mucus.mucusOn(DateTime(2026, 7, 12)))!.type,
        CervicalMucusType.eggWhite,
      );

      final settings = DriftSettingsRepository(db);
      await settings.set(SettingKeys.temperatureUnit, 'fahrenheit');
      expect(await settings.get(SettingKeys.temperatureUnit), 'fahrenheit');
    },
  );
}
