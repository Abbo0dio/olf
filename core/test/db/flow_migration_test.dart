import 'dart:io';

import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// Schema v2 → v3 (p1.2): the `daily_flows` per-day table is added. Purely
/// additive — nothing is backfilled, and existing periods must be untouched.
///
/// Hand-rolled like `period_migration_test.dart`: a real on-disk v2 file is
/// built, then opened through [AppDatabase] so `migration.onUpgrade` runs.
void main() {
  late Directory tmp;
  late File dbFile;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('olf_flow_migration_test');
    dbFile = File('${tmp.path}/olf.db');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  int unixSeconds(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  /// Write [dbFile] at exactly the v2 shape with [periodStart]/[periodEnd] as a
  /// single stored period, then close it.
  void createV2Database(DateTime periodStart, DateTime periodEnd) {
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
    raw.execute('PRAGMA user_version = 2;');
    raw.dispose();
  }

  test('opening a v2 database upgrades through to the current version, '
      'adding daily_flows along the way', () async {
    createV2Database(DateTime(2026, 7, 10), DateTime(2026, 7, 14));

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, db.schemaVersion);
    expect(db.schemaVersion, 6);

    // New table exists with the expected shape.
    final columns = await db
        .customSelect("PRAGMA table_info('daily_flows')")
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
        'clot_size',
        'created_at',
        'updated_at',
      }),
    );
    expect(byName['date'], ('INTEGER', true, true)); // primary key
    expect(byName['intensity'], ('TEXT', true, false));
    expect(byName['clot_size'], ('TEXT', false, false)); // nullable

    // The later v4 migration also ran and seeded the symptom catalogue.
    final types = await DriftSymptomRepository(db).activeTypes();
    expect(types.map((t) => t.name), kBuiltInSymptomNames);

    // The existing period is untouched.
    final period = (await DriftPeriodRepository(db).allPeriods()).single;
    expect(period.startDate, DateTime(2026, 7, 10));
    expect(period.endDate, DateTime(2026, 7, 14));

    // And the new table is usable.
    final flow = DriftDailyFlowRepository(db, now: () => DateTime(2026, 7, 12));
    await flow.setFlow(DateTime(2026, 7, 12), intensity: FlowIntensity.heavy);
    expect(
      (await flow.flowOn(DateTime(2026, 7, 12)))!.intensity,
      FlowIntensity.heavy,
    );
  });
}
