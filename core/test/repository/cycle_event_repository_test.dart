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

  group('pregnancy-end events (p1.11)', () {
    test('logPregnancyEnd stores a date-only row of the right type', () async {
      final lossId = await repo.logPregnancyEnd(
        PregnancyEndKind.loss,
        DateTime(2026, 4, 10, 22, 5),
      );
      final birthId = await repo.logPregnancyEnd(
        PregnancyEndKind.birth,
        DateTime(2026, 9, 2),
      );

      final events = await repo.pregnancyEvents();
      expect(events.map((e) => e.id), [lossId, birthId]); // oldest first
      expect(events.first.kind, PregnancyEndKind.loss);
      expect(events.first.date, DateTime(2026, 4, 10)); // time dropped
      expect(events.last.kind, PregnancyEndKind.birth);
    });

    test('pregnancyEvents excludes periodStart rows', () async {
      await repo.logPeriodStart(DateTime(2026, 1, 1));
      await repo.logPregnancyEnd(PregnancyEndKind.birth, DateTime(2026, 3, 1));
      await repo.logPeriodStart(DateTime(2026, 5, 1));

      final events = await repo.pregnancyEvents();
      expect(events, hasLength(1));
      expect(events.single.kind, PregnancyEndKind.birth);
    });

    test('deleteEvent removes a pregnancy-end row', () async {
      final id = await repo.logPregnancyEnd(
        PregnancyEndKind.loss,
        DateTime(2026, 4, 10),
      );
      await repo.deleteEvent(id);
      expect(await repo.pregnancyEvents(), isEmpty);
    });

    test('watchPregnancyEvents emits the list on insert and delete', () async {
      final emissions = <List<PregnancyEndKind>>[];
      final sub = repo.watchPregnancyEvents().listen(
        (list) => emissions.add([for (final e in list) e.kind]),
      );

      await pumpEventQueue();
      final id = await repo.logPregnancyEnd(
        PregnancyEndKind.loss,
        DateTime(2026, 4, 10),
      );
      await pumpEventQueue();
      await repo.deleteEvent(id);
      await pumpEventQueue();

      await sub.cancel();
      expect(emissions, [
        <PregnancyEndKind>[],
        [PregnancyEndKind.loss],
        <PregnancyEndKind>[],
      ]);
    });
  });
}
