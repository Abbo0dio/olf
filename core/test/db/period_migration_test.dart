import 'dart:io';

import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// Schema v1 → v2 (p1.1): the `periods` interval table is added and every
/// `periodStart` event is carried over as an open-ended period.
///
/// This is hand-rolled: a real on-disk SQLite file is created at the v1 shape,
/// then opened through [AppDatabase] so `migration.onUpgrade` runs for real.
/// (Adopting `drift_dev schema` snapshot tooling is a tracked follow-up for the
/// next migration — see DEVELOPMENT_PLAN.md §9.)
void main() {
  late Directory tmp;
  late File dbFile;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('olf_migration_test');
    dbFile = File('${tmp.path}/olf.db');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  int unixSeconds(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  /// Write [dbFile] with exactly the v1 schema and [starts] as `periodStart`
  /// rows, then close it.
  void createV1Database(List<DateTime> starts) {
    final raw = sqlite3.open(dbFile.path);
    raw.execute('''
      CREATE TABLE "cycle_events" (
        "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "type" TEXT NOT NULL,
        "date" INTEGER NOT NULL,
        "created_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
    ''');
    for (final start in starts) {
      raw.execute(
        'INSERT INTO cycle_events (type, date, created_at) VALUES (?, ?, ?)',
        ['periodStart', unixSeconds(start), unixSeconds(start)],
      );
    }
    raw.execute('PRAGMA user_version = 1;');
    raw.dispose();
  }

  test(
    'opening a v1 database upgrades it to v2 and keeps every start',
    () async {
      final starts = [DateTime(2026, 6, 1), DateTime(2026, 7, 3)];
      createV1Database(starts);

      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      // Force the upgrade to run.
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.first, 2);
      expect(db.schemaVersion, 2);

      // The new table exists with the expected shape.
      final columns = await db
          .customSelect("PRAGMA table_info('periods')")
          .get();
      final types = {
        for (final row in columns)
          row.data['name'] as String: (row.data['type'] as String)
              .toUpperCase(),
      };
      expect(
        types.keys,
        containsAll(<String>{
          'id',
          'start_date',
          'end_date',
          'created_at',
          'updated_at',
        }),
      );
      expect(types['start_date'], 'INTEGER');
      expect(types['end_date'], 'INTEGER');

      // Every v1 periodStart became an open-ended period, dates intact.
      final repo = DriftPeriodRepository(db);
      final periods = await repo.allPeriods();
      expect(periods.map((p) => p.startDate), [
        DateTime(2026, 7, 3),
        DateTime(2026, 6, 1),
      ]);
      expect(periods.every((p) => p.endDate == null), isTrue);

      // The original event log is left in place (p1.11 still uses it).
      final events = await db
          .customSelect('SELECT COUNT(*) AS n FROM cycle_events')
          .getSingle();
      expect(events.data['n'], 2);
    },
  );

  test(
    'a fresh v2 database has no rows to migrate and works normally',
    () async {
      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      final repo = DriftPeriodRepository(db, now: () => DateTime(2026, 8, 28));
      expect(await repo.allPeriods(), isEmpty);

      await repo.addPeriod(
        PeriodDraft(start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 4)),
      );
      expect((await repo.allPeriods()).single.startDate, DateTime(2026, 8, 1));

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.first, 2);
    },
  );
}
