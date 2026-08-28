import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late PeriodRepository repo;

  // Fixed "now" so future-date validation and the updatedAt stamp are
  // deterministic. Well after every date the tests log.
  final now = DateTime(2026, 8, 28, 9, 30);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftPeriodRepository(db, now: () => now);
  });
  tearDown(() => db.close());

  PeriodDraft draft(DateTime start, [DateTime? end]) =>
      PeriodDraft(start: start, end: end);

  test('addPeriod stores date-only start/end and returns the id', () async {
    final id = await repo.addPeriod(
      draft(DateTime(2026, 8, 1, 14, 30), DateTime(2026, 8, 5, 22)),
    );

    final periods = await repo.allPeriods();
    expect(periods, hasLength(1));
    expect(periods.single.id, id);
    expect(periods.single.startDate, DateTime(2026, 8, 1));
    expect(periods.single.endDate, DateTime(2026, 8, 5));
    expect(periods.single.createdAt, now);
    expect(periods.single.updatedAt, now);
  });

  test('addPeriod accepts an open-ended period', () async {
    await repo.addPeriod(draft(DateTime(2026, 8, 20)));
    expect((await repo.allPeriods()).single.endDate, isNull);
  });

  test('allPeriods is ordered most-recent-start first', () async {
    await repo.addPeriod(draft(DateTime(2026, 6, 1), DateTime(2026, 6, 5)));
    await repo.addPeriod(draft(DateTime(2026, 8, 1), DateTime(2026, 8, 4)));
    await repo.addPeriod(draft(DateTime(2026, 7, 1), DateTime(2026, 7, 3)));

    expect((await repo.allPeriods()).map((p) => p.startDate.month), [8, 7, 6]);
  });

  test('addPeriod rejects an overlap and writes nothing', () async {
    await repo.addPeriod(draft(DateTime(2026, 8, 10), DateTime(2026, 8, 15)));

    await expectLater(
      repo.addPeriod(draft(DateTime(2026, 8, 12), DateTime(2026, 8, 20))),
      throwsA(
        isA<PeriodValidationException>().having(
          (e) => e.error,
          'error',
          PeriodValidationError.overlapsExisting,
        ),
      ),
    );

    expect(await repo.allPeriods(), hasLength(1));
  });

  test('addPeriod rejects an impossible range', () async {
    await expectLater(
      repo.addPeriod(draft(DateTime(2026, 8, 10), DateTime(2026, 8, 5))),
      throwsA(
        isA<PeriodValidationException>().having(
          (e) => e.error,
          'error',
          PeriodValidationError.endBeforeStart,
        ),
      ),
    );
    expect(await repo.allPeriods(), isEmpty);
  });

  test('addPeriod rejects a future start', () async {
    await expectLater(
      repo.addPeriod(draft(DateTime(2026, 8, 29))),
      throwsA(
        isA<PeriodValidationException>().having(
          (e) => e.error,
          'error',
          PeriodValidationError.startInFuture,
        ),
      ),
    );
  });

  test(
    'updatePeriod changes only the target row (no forward cascade)',
    () async {
      final aId = await repo.addPeriod(
        draft(DateTime(2026, 7, 1), DateTime(2026, 7, 6)),
      );
      final bId = await repo.addPeriod(
        draft(DateTime(2026, 8, 10), DateTime(2026, 8, 15)),
      );

      final bBefore = (await repo.allPeriods()).firstWhere((p) => p.id == bId);

      await repo.updatePeriod(
        aId,
        draft(DateTime(2026, 7, 2), DateTime(2026, 7, 9)),
      );

      final all = await repo.allPeriods();
      final aAfter = all.firstWhere((p) => p.id == aId);
      final bAfter = all.firstWhere((p) => p.id == bId);

      expect(aAfter.startDate, DateTime(2026, 7, 2));
      expect(aAfter.endDate, DateTime(2026, 7, 9));
      // The other period is untouched, timestamps included.
      expect(bAfter, bBefore);
    },
  );

  test('updatePeriod re-validates against the other periods', () async {
    final aId = await repo.addPeriod(
      draft(DateTime(2026, 7, 1), DateTime(2026, 7, 6)),
    );
    await repo.addPeriod(draft(DateTime(2026, 8, 10), DateTime(2026, 8, 15)));

    await expectLater(
      repo.updatePeriod(
        aId,
        draft(DateTime(2026, 8, 12), DateTime(2026, 8, 13)),
      ),
      throwsA(isA<PeriodValidationException>()),
    );

    // The failed edit left the row as it was.
    expect(
      (await repo.allPeriods()).firstWhere((p) => p.id == aId).startDate,
      DateTime(2026, 7, 1),
    );
  });

  test('updatePeriod lets a period keep / shrink its own range', () async {
    final id = await repo.addPeriod(
      draft(DateTime(2026, 8, 10), DateTime(2026, 8, 15)),
    );
    await repo.updatePeriod(
      id,
      draft(DateTime(2026, 8, 11), DateTime(2026, 8, 12)),
    );
    final row = (await repo.allPeriods()).single;
    expect(row.startDate, DateTime(2026, 8, 11));
    expect(row.endDate, DateTime(2026, 8, 12));
  });

  test('updatePeriod on a missing id is a no-op', () async {
    await repo.addPeriod(draft(DateTime(2026, 8, 10), DateTime(2026, 8, 15)));
    await repo.updatePeriod(999, draft(DateTime(2026, 1, 1)));
    expect(await repo.allPeriods(), hasLength(1));
  });

  test('deletePeriod removes the row; a missing id is a no-op', () async {
    final id = await repo.addPeriod(
      draft(DateTime(2026, 8, 10), DateTime(2026, 8, 15)),
    );
    await repo.deletePeriod(999);
    expect(await repo.allPeriods(), hasLength(1));
    await repo.deletePeriod(id);
    expect(await repo.allPeriods(), isEmpty);
  });

  test('watchPeriods emits on add, update and delete', () async {
    final counts = <int>[];
    final sub = repo.watchPeriods().listen((rows) => counts.add(rows.length));
    await pumpEventQueue();

    final id = await repo.addPeriod(
      draft(DateTime(2026, 8, 10), DateTime(2026, 8, 15)),
    );
    await pumpEventQueue();
    await repo.updatePeriod(
      id,
      draft(DateTime(2026, 8, 10), DateTime(2026, 8, 14)),
    );
    await pumpEventQueue();
    await repo.deletePeriod(id);
    await pumpEventQueue();

    await sub.cancel();
    expect(counts, [0, 1, 1, 0]);
  });
}
