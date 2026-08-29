import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftBirthControlRepository repo;
  var clock = DateTime(2026, 8, 29, 9);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftBirthControlRepository(db, now: () => clock);
  });
  tearDown(() => db.close());

  test('switchTo sets a current entry, dated today by default', () async {
    final entry = await repo.switchTo(BirthControlMethod.pill);
    expect(entry.method, BirthControlMethod.pill);
    expect(entry.startedOn, DateTime(2026, 8, 29));
    expect(entry.endedOn, isNull);

    final current = await repo.current();
    expect(current!.method, BirthControlMethod.pill);
  });

  test('switchTo again closes the previous entry the day before', () async {
    await repo.switchTo(
      BirthControlMethod.pill,
      startedOn: DateTime(2026, 1, 1),
    );
    clock = DateTime(2026, 8, 29, 9);
    await repo.switchTo(
      BirthControlMethod.ring,
      startedOn: DateTime(2026, 8, 1),
    );

    final all = await repo.watchAll().first;
    expect(all.map((e) => e.method), [
      BirthControlMethod.ring,
      BirthControlMethod.pill,
    ]);
    final pill = all.firstWhere((e) => e.method == BirthControlMethod.pill);
    expect(pill.endedOn, DateTime(2026, 7, 31));
    expect(
      await repo.current().then((e) => e!.method),
      BirthControlMethod.ring,
    );
  });

  test('same-day switch ends the prior entry on its own start date', () async {
    await repo.switchTo(
      BirthControlMethod.pill,
      startedOn: DateTime(2026, 8, 29),
    );
    await repo.switchTo(
      BirthControlMethod.patch,
      startedOn: DateTime(2026, 8, 29),
    );

    final pill = (await repo.watchAll().first).firstWhere(
      (e) => e.method == BirthControlMethod.pill,
    );
    expect(pill.endedOn, DateTime(2026, 8, 29));
  });

  test('switchTo rejects a future start', () async {
    expect(
      () => repo.switchTo(
        BirthControlMethod.pill,
        startedOn: DateTime(2026, 8, 30),
      ),
      throwsA(
        isA<BirthControlException>().having(
          (e) => e.error,
          'error',
          BirthControlError.startInFuture,
        ),
      ),
    );
  });

  test('stop closes the current entry; no-op when nothing is open', () async {
    await repo.stop(); // nothing open
    expect(await repo.current(), isNull);

    await repo.switchTo(
      BirthControlMethod.pill,
      startedOn: DateTime(2026, 8, 1),
    );
    await repo.stop(endedOn: DateTime(2026, 8, 20));
    expect(await repo.current(), isNull);
    expect((await repo.watchAll().first).single.endedOn, DateTime(2026, 8, 20));
  });

  test('edit validates the range', () async {
    final e = await repo.switchTo(
      BirthControlMethod.pill,
      startedOn: DateTime(2026, 8, 1),
    );
    expect(
      () => repo.edit(
        e.id,
        startedOn: DateTime(2026, 8, 10),
        endedOn: DateTime(2026, 8, 5),
      ),
      throwsA(isA<BirthControlException>()),
    );
    await repo.edit(e.id, startedOn: DateTime(2026, 7, 1), notes: 'switched');
    expect((await repo.watchAll().first).single.notes, 'switched');
  });

  test('watchCurrent emits null then the new method', () async {
    final seen = <BirthControlMethod?>[];
    final sub = repo.watchCurrent().listen((e) => seen.add(e?.method));
    await pumpEventQueue();
    await repo.switchTo(BirthControlMethod.injection);
    await pumpEventQueue();
    await sub.cancel();
    expect(seen, [null, BirthControlMethod.injection]);
  });
}
