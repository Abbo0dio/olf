import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DailyFlowRepository repo;

  final now = DateTime(2026, 8, 28, 9, 30);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftDailyFlowRepository(db, now: () => now);
  });
  tearDown(() => db.close());

  test(
    'setFlow stores a date-only row with intensity and optional clot',
    () async {
      await repo.setFlow(
        DateTime(2026, 8, 20, 22, 15),
        intensity: FlowIntensity.medium,
        clotSize: ClotSize.small,
      );

      final row = await repo.flowOn(DateTime(2026, 8, 20));
      expect(row, isNotNull);
      expect(row!.date, DateTime(2026, 8, 20));
      expect(row.intensity, FlowIntensity.medium);
      expect(row.clotSize, ClotSize.small);
      expect(row.createdAt, now);
      expect(row.updatedAt, now);
    },
  );

  test('setFlow without a clot leaves clot_size null', () async {
    await repo.setFlow(DateTime(2026, 8, 20), intensity: FlowIntensity.light);
    expect((await repo.flowOn(DateTime(2026, 8, 20)))!.clotSize, isNull);
  });

  test('setFlow on an existing day upserts and preserves created_at', () async {
    await repo.setFlow(DateTime(2026, 8, 20), intensity: FlowIntensity.light);

    final later = DateTime(2026, 8, 21, 8);
    repo = DriftDailyFlowRepository(db, now: () => later);
    await repo.setFlow(
      DateTime(2026, 8, 20),
      intensity: FlowIntensity.heavy,
      clotSize: ClotSize.large,
    );

    final rows = await repo.watchAll().first;
    expect(rows, hasLength(1)); // still one row for the day
    final row = rows.single;
    expect(row.intensity, FlowIntensity.heavy);
    expect(row.clotSize, ClotSize.large);
    expect(row.createdAt, now); // original
    expect(row.updatedAt, later); // bumped
  });

  test('setFlow can drop a previously recorded clot', () async {
    await repo.setFlow(
      DateTime(2026, 8, 20),
      intensity: FlowIntensity.heavy,
      clotSize: ClotSize.large,
    );
    await repo.setFlow(DateTime(2026, 8, 20), intensity: FlowIntensity.medium);
    expect((await repo.flowOn(DateTime(2026, 8, 20)))!.clotSize, isNull);
  });

  test('clearFlow removes the day; a missing day is a no-op', () async {
    await repo.setFlow(DateTime(2026, 8, 20), intensity: FlowIntensity.light);
    await repo.clearFlow(DateTime(2026, 8, 19)); // no such day
    expect(await repo.flowOn(DateTime(2026, 8, 20)), isNotNull);
    await repo.clearFlow(DateTime(2026, 8, 20));
    expect(await repo.flowOn(DateTime(2026, 8, 20)), isNull);
  });

  test('flowOn returns null for an unlogged day', () async {
    expect(await repo.flowOn(DateTime(2026, 1, 1)), isNull);
  });

  test('watchAll emits on set and clear', () async {
    final counts = <int>[];
    final sub = repo.watchAll().listen((rows) => counts.add(rows.length));
    await pumpEventQueue();

    await repo.setFlow(DateTime(2026, 8, 20), intensity: FlowIntensity.light);
    await pumpEventQueue();
    await repo.setFlow(DateTime(2026, 8, 21), intensity: FlowIntensity.heavy);
    await pumpEventQueue();
    await repo.clearFlow(DateTime(2026, 8, 20));
    await pumpEventQueue();

    await sub.cancel();
    expect(counts, [0, 1, 2, 1]);
  });

  test('flow is independent of periods (no cascade)', () async {
    final periods = DriftPeriodRepository(db, now: () => now);
    final id = await periods.addPeriod(
      PeriodDraft(start: DateTime(2026, 8, 18), end: DateTime(2026, 8, 22)),
    );
    await repo.setFlow(DateTime(2026, 8, 20), intensity: FlowIntensity.heavy);

    await periods.deletePeriod(id);

    final row = await repo.flowOn(DateTime(2026, 8, 20));
    expect(row, isNotNull);
    expect(row!.intensity, FlowIntensity.heavy);
  });
}
