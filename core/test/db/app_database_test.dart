import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('schemaVersion is 4', () {
    expect(db.schemaVersion, 4);
  });

  test(
    'onCreate builds cycle_events with the expected columns and types',
    () async {
      final rows = await db
          .customSelect("PRAGMA table_info('cycle_events')")
          .get();
      final types = {
        for (final r in rows)
          r.data['name'] as String: (r.data['type'] as String).toUpperCase(),
      };

      expect(
        types.keys,
        containsAll(<String>{'id', 'type', 'date', 'created_at'}),
      );
      expect(types['id'], 'INTEGER');
      expect(types['type'], 'TEXT');
      expect(types['date'], 'INTEGER'); // drift stores DateTime as unix seconds
      expect(types['created_at'], 'INTEGER');
    },
  );

  test(
    'onCreate builds periods with the expected columns and types (v2)',
    () async {
      final rows = await db.customSelect("PRAGMA table_info('periods')").get();
      final columns = {
        for (final r in rows)
          r.data['name'] as String: (
            (r.data['type'] as String).toUpperCase(),
            (r.data['notnull'] as int) == 1,
          ),
      };

      expect(
        columns.keys,
        containsAll(<String>{
          'id',
          'start_date',
          'end_date',
          'created_at',
          'updated_at',
        }),
      );
      expect(columns['start_date'], ('INTEGER', true));
      expect(columns['end_date'], ('INTEGER', false)); // nullable
      expect(columns['updated_at'], ('INTEGER', true));
    },
  );

  test(
    'onCreate builds daily_flows with the expected columns and types (v3)',
    () async {
      final rows = await db
          .customSelect("PRAGMA table_info('daily_flows')")
          .get();
      final columns = {
        for (final r in rows)
          r.data['name'] as String: (
            (r.data['type'] as String).toUpperCase(),
            (r.data['notnull'] as int) == 1,
            (r.data['pk'] as int) != 0,
          ),
      };

      expect(
        columns.keys,
        containsAll(<String>{
          'date',
          'intensity',
          'clot_size',
          'created_at',
          'updated_at',
        }),
      );
      expect(columns['date'], ('INTEGER', true, true)); // primary key
      expect(columns['intensity'], ('TEXT', true, false));
      expect(columns['clot_size'], ('TEXT', false, false)); // nullable
    },
  );

  test(
    'onCreate builds symptom_types with the expected columns and types (v4)',
    () async {
      final rows = await db
          .customSelect("PRAGMA table_info('symptom_types')")
          .get();
      final columns = {
        for (final r in rows)
          r.data['name'] as String: (
            (r.data['type'] as String).toUpperCase(),
            (r.data['notnull'] as int) == 1,
          ),
      };

      expect(
        columns.keys,
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
      expect(columns['name'], ('TEXT', true));
      expect(columns['sort_order'], ('INTEGER', true));
      expect(columns['is_built_in'], ('INTEGER', true)); // bool as 0/1
      expect(columns['archived_at'], ('INTEGER', false)); // nullable
    },
  );

  test(
    'onCreate seeds symptom_types with the built-in names in order',
    () async {
      final rows = await db
          .customSelect('SELECT name FROM symptom_types ORDER BY sort_order')
          .get();
      expect(
        rows.map((r) => r.data['name'] as String).toList(),
        kBuiltInSymptomNames,
      );
    },
  );

  test(
    'onCreate builds daily_symptom_entries with a composite primary key (v4)',
    () async {
      final rows = await db
          .customSelect("PRAGMA table_info('daily_symptom_entries')")
          .get();
      final columns = {
        for (final r in rows)
          r.data['name'] as String: (
            (r.data['type'] as String).toUpperCase(),
            (r.data['notnull'] as int) == 1,
            (r.data['pk'] as int) != 0,
          ),
      };

      expect(
        columns.keys,
        containsAll(<String>{'date', 'symptom_type_id', 'created_at'}),
      );
      expect(columns['date'], ('INTEGER', true, true)); // part of PK
      expect(columns['symptom_type_id'], ('INTEGER', true, true)); // part of PK
      expect(columns['created_at'], ('INTEGER', true, false));
    },
  );

  test(
    'daily_symptom_entries enforces the symptom_type_id foreign key',
    () async {
      await db.customSelect('SELECT 1').get(); // force open (runs beforeOpen)
      expect(
        () => db.customStatement(
          'INSERT INTO daily_symptom_entries (date, symptom_type_id, created_at) '
          'VALUES (0, 999999, 0)',
        ),
        throwsA(anything),
      );
    },
  );

  test('a fresh database reports user_version == schemaVersion', () async {
    await db.customSelect('SELECT 1').get(); // force open → runs onCreate
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.data.values.first, db.schemaVersion);
  });

  test(
    'migration.onUpgrade is wired (no-op at v1) and beforeOpen enables FKs',
    () async {
      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(row.data.values.first, 1);
    },
  );
}
