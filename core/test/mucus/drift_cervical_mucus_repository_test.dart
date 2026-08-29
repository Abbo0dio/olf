import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftCervicalMucusRepository repo;

  final now = DateTime(2026, 8, 28, 7);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftCervicalMucusRepository(db, now: () => now);
  });
  tearDown(() => db.close());

  test('setMucus stores a date-only row', () async {
    await repo.setMucus(DateTime(2026, 8, 20, 23), CervicalMucusType.creamy);

    final row = await repo.mucusOn(DateTime(2026, 8, 20));
    expect(row, isNotNull);
    expect(row!.date, DateTime(2026, 8, 20));
    expect(row.type, CervicalMucusType.creamy);
    expect(row.createdAt, now);
  });

  test('setMucus upserts and preserves created_at', () async {
    await repo.setMucus(DateTime(2026, 8, 20), CervicalMucusType.sticky);

    final later = DateTime(2026, 8, 21, 7);
    repo = DriftCervicalMucusRepository(db, now: () => later);
    await repo.setMucus(DateTime(2026, 8, 20), CervicalMucusType.eggWhite);

    final rows = await repo.watchAll().first;
    expect(rows, hasLength(1));
    expect(rows.single.type, CervicalMucusType.eggWhite);
    expect(rows.single.createdAt, now);
    expect(rows.single.updatedAt, later);
  });

  test('clearMucus removes the day; a missing day is a no-op', () async {
    await repo.setMucus(DateTime(2026, 8, 20), CervicalMucusType.watery);
    await repo.clearMucus(DateTime(2026, 8, 19));
    expect(await repo.mucusOn(DateTime(2026, 8, 20)), isNotNull);
    await repo.clearMucus(DateTime(2026, 8, 20));
    expect(await repo.mucusOn(DateTime(2026, 8, 20)), isNull);
  });

  test('watchAll emits on set and clear, newest first', () async {
    final counts = <int>[];
    final sub = repo.watchAll().listen((rows) => counts.add(rows.length));
    await pumpEventQueue();

    await repo.setMucus(DateTime(2026, 8, 10), CervicalMucusType.dry);
    await pumpEventQueue();
    await repo.setMucus(DateTime(2026, 8, 12), CervicalMucusType.creamy);
    await pumpEventQueue();
    await repo.clearMucus(DateTime(2026, 8, 10));
    await pumpEventQueue();

    await sub.cancel();
    expect(counts, [0, 1, 2, 1]);
  });
}
