import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftReminderRepository repo;
  var clock = DateTime(2026, 8, 29, 9);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftReminderRepository(db, now: () => clock);
  });
  tearDown(() => db.close());

  ReminderSchedule schedule(int h, int m, {bool enabled = true}) =>
      ReminderSchedule(
        kind: ReminderKind.medication,
        hour: h,
        minute: m,
        enabled: enabled,
      );

  test('get returns null before anything is saved', () async {
    expect(await repo.get(ReminderKind.medication), isNull);
  });

  test('save inserts then updates the same single row', () async {
    await repo.save(schedule(9, 0, enabled: true));
    expect(
      await repo.get(ReminderKind.medication),
      schedule(9, 0, enabled: true),
    );

    clock = DateTime(2026, 8, 30, 9);
    await repo.save(schedule(21, 30, enabled: false));
    expect(
      await repo.get(ReminderKind.medication),
      schedule(21, 30, enabled: false),
    );

    // still exactly one row (UNIQUE (kind))
    final count = await db
        .customSelect('SELECT COUNT(*) AS c FROM reminders')
        .getSingle();
    expect(count.data['c'], 1);
  });

  test('save rejects an out-of-range time', () async {
    expect(
      () => repo.save(schedule(25, 0)),
      throwsA(
        isA<ReminderException>().having(
          (e) => e.error,
          'error',
          ReminderError.hourOutOfRange,
        ),
      ),
    );
    expect(await repo.get(ReminderKind.medication), isNull);
  });

  test('watch emits null, then each saved value', () async {
    final seen = <ReminderSchedule?>[];
    final sub = repo.watch(ReminderKind.medication).listen(seen.add);
    await pumpEventQueue();
    await repo.save(schedule(8, 15, enabled: true));
    await pumpEventQueue();
    await repo.save(schedule(8, 15, enabled: false));
    await pumpEventQueue();
    await sub.cancel();

    expect(seen.first, isNull);
    expect(seen.last, schedule(8, 15, enabled: false));
  });
}
