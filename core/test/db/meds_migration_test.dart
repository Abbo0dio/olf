import 'dart:io';

import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// Schema v5 → v6 (p1.7): adds `medications`, `birth_control_entries` and the
/// `reminders` table. Purely additive — existing rows are untouched.
///
/// Hand-rolled like the earlier migration tests: a real on-disk v5 file is
/// built, then opened through [AppDatabase] so `migration.onUpgrade` runs.
void main() {
  late Directory tmp;
  late File dbFile;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('olf_meds_migration_test');
    dbFile = File('${tmp.path}/olf.db');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  int unixSeconds(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  /// Write [dbFile] at exactly the v5 shape with a couple of existing rows,
  /// then close it.
  void createV5Database(DateTime periodStart, DateTime periodEnd) {
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
      CREATE TABLE "bbt_entries" (
        "date" INTEGER NOT NULL PRIMARY KEY,
        "temp_celsius" REAL NOT NULL,
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
      'INSERT INTO app_settings (key, value, updated_at) VALUES (?, ?, ?)',
      ['temperature_unit', 'fahrenheit', unixSeconds(periodStart)],
    );
    raw.execute('PRAGMA user_version = 5;');
    raw.dispose();
  }

  test(
    'opening a v5 database upgrades it to v6 and adds the new tables',
    () async {
      createV5Database(DateTime(2026, 7, 10), DateTime(2026, 7, 14));

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.first, db.schemaVersion);
      expect(db.schemaVersion, 7);

      final newTables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name IN "
            "('medications', 'birth_control_entries', 'reminders')",
          )
          .get();
      expect(newTables.map((r) => r.data['name'] as String).toSet(), {
        'medications',
        'birth_control_entries',
        'reminders',
      });

      // Existing rows survived untouched.
      final period = (await DriftPeriodRepository(db).allPeriods()).single;
      expect(period.startDate, DateTime(2026, 7, 10));
      expect(
        await DriftSettingsRepository(db).get(SettingKeys.temperatureUnit),
        'fahrenheit',
      );

      // The new tables are usable.
      final meds = DriftMedicationRepository(
        db,
        now: () => DateTime(2026, 7, 12),
      );
      await meds.add('Iron', dosage: '50 mg');
      expect((await meds.activeMedications()).single.name, 'Iron');

      final bc = DriftBirthControlRepository(
        db,
        now: () => DateTime(2026, 7, 12),
      );
      await bc.switchTo(BirthControlMethod.pill);
      expect((await bc.current())!.method, BirthControlMethod.pill);

      final reminders = DriftReminderRepository(
        db,
        now: () => DateTime(2026, 7, 12),
      );
      await reminders.save(
        const ReminderSchedule(
          kind: ReminderKind.medication,
          hour: 9,
          minute: 0,
          enabled: true,
        ),
      );
      expect((await reminders.get(ReminderKind.medication))!.hour, 9);
    },
  );

  test('the reminders table keeps one row per kind (UNIQUE (kind))', () async {
    createV5Database(DateTime(2026, 7, 10), DateTime(2026, 7, 14));
    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get(); // force open / migrate

    await db.customStatement(
      "INSERT INTO reminders (kind, hour, minute, enabled, created_at, updated_at) "
      "VALUES ('medication', 9, 0, 1, 0, 0)",
    );
    expect(
      () => db.customStatement(
        "INSERT INTO reminders (kind, hour, minute, enabled, created_at, updated_at) "
        "VALUES ('medication', 21, 0, 1, 0, 0)",
      ),
      throwsA(anything),
    );
  });
}
