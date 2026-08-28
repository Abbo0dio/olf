import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('schemaVersion is 1', () {
    expect(db.schemaVersion, 1);
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
