import 'dart:io';

import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// Schema v3 → v4 (p1.5): the `symptom_types` catalogue and
/// `daily_symptom_entries` log are added, and the catalogue is seeded with the
/// built-in names. Purely additive — existing periods and flows are untouched.
///
/// Hand-rolled like `flow_migration_test.dart`: a real on-disk v3 file is built,
/// then opened through [AppDatabase] so `migration.onUpgrade` runs.
void main() {
  late Directory tmp;
  late File dbFile;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('olf_symptom_migration_test');
    dbFile = File('${tmp.path}/olf.db');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  int unixSeconds(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  /// Write [dbFile] at exactly the v3 shape with one period and one flow row,
  /// then close it.
  void createV3Database(DateTime periodStart, DateTime periodEnd) {
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
    raw.execute('PRAGMA user_version = 3;');
    raw.dispose();
  }

  test(
    'opening a v3 database upgrades it to v4 and seeds the catalogue',
    () async {
      createV3Database(DateTime(2026, 7, 10), DateTime(2026, 7, 14));

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.first, db.schemaVersion);
      expect(db.schemaVersion, 7);

      // symptom_types has the expected shape.
      final typeCols = await db
          .customSelect("PRAGMA table_info('symptom_types')")
          .get();
      final byName = {
        for (final row in typeCols)
          row.data['name'] as String: (
            (row.data['type'] as String).toUpperCase(),
            (row.data['notnull'] as int) == 1,
          ),
      };
      expect(
        byName.keys,
        containsAll(<String>{
          'id',
          'name',
          'sort_order',
          'is_built_in',
          'archived_at',
          'created_at',
          'updated_at',
        }),
      );
      expect(byName['name'], ('TEXT', true));
      expect(byName['sort_order'], ('INTEGER', true));
      expect(byName['archived_at'], ('INTEGER', false)); // nullable

      // daily_symptom_entries has the composite primary key.
      final entryCols = await db
          .customSelect("PRAGMA table_info('daily_symptom_entries')")
          .get();
      final entryByName = {
        for (final row in entryCols)
          row.data['name'] as String: (
            (row.data['type'] as String).toUpperCase(),
            (row.data['pk'] as int) != 0,
          ),
      };
      expect(
        entryByName.keys,
        containsAll(<String>{'date', 'symptom_type_id', 'created_at'}),
      );
      expect(entryByName['date'], ('INTEGER', true));
      expect(entryByName['symptom_type_id'], ('INTEGER', true));

      // The catalogue was seeded with the built-ins, in order.
      final repo = DriftSymptomRepository(db, now: () => DateTime(2026, 7, 15));
      final types = await repo.activeTypes();
      expect(types.map((t) => t.name), kBuiltInSymptomNames);
      expect(types.every((t) => t.isBuiltIn), isTrue);

      // Existing period and flow rows survived untouched.
      final period = (await DriftPeriodRepository(db).allPeriods()).single;
      expect(period.startDate, DateTime(2026, 7, 10));
      expect(period.endDate, DateTime(2026, 7, 14));
      final flow = DriftDailyFlowRepository(db);
      expect(
        (await flow.flowOn(DateTime(2026, 7, 12)))!.intensity,
        FlowIntensity.heavy,
      );

      // And the new tables are usable.
      await repo.setSymptom(
        DateTime(2026, 7, 12),
        types.first.id,
        present: true,
      );
      expect(await repo.symptomsOn(DateTime(2026, 7, 12)), {types.first.id});
    },
  );
}
