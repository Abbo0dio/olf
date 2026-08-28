import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late CycleEventRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftCycleEventRepository(db);
  });
  tearDown(() => db.close());

  test('logPeriodStart stores a date-only periodStart event', () async {
    final id = await repo.logPeriodStart(DateTime(2026, 8, 27, 14, 30));

    final event = await repo.mostRecentPeriodStart();
    expect(event, isNotNull);
    expect(event!.id, id);
    expect(event.type, CycleEventType.periodStart);
    expect(event.date, DateTime(2026, 8, 27)); // time-of-day dropped
  });

  test('mostRecentPeriodStart returns null when nothing is logged', () async {
    expect(await repo.mostRecentPeriodStart(), isNull);
  });

  test(
    'mostRecentPeriodStart picks the latest date, then the latest id',
    () async {
      await repo.logPeriodStart(DateTime(2026, 6, 1));
      await repo.logPeriodStart(DateTime(2026, 8, 1));
      final newerSameDay = await repo.logPeriodStart(DateTime(2026, 8, 1));

      final event = await repo.mostRecentPeriodStart();
      expect(event!.id, newerSameDay);
      expect(event.date, DateTime(2026, 8, 1));
    },
  );

  test('deleteEvent removes the row', () async {
    final id = await repo.logPeriodStart(DateTime(2026, 8, 27));
    await repo.deleteEvent(id);
    expect(await repo.mostRecentPeriodStart(), isNull);
  });

  test('deleteEvent on a missing id is a no-op', () async {
    await repo.logPeriodStart(DateTime(2026, 8, 27));
    await repo.deleteEvent(999);
    expect(await repo.mostRecentPeriodStart(), isNotNull);
  });

  test('watchMostRecentPeriodStart emits on insert and delete', () async {
    final emissions = <int?>[];
    final sub = repo.watchMostRecentPeriodStart().listen(
      (e) => emissions.add(e?.id),
    );

    await pumpEventQueue();
    final id = await repo.logPeriodStart(DateTime(2026, 8, 27));
    await pumpEventQueue();
    await repo.deleteEvent(id);
    await pumpEventQueue();

    await sub.cancel();
    expect(emissions, [null, id, null]);
  });
}
