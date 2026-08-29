import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftBbtRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftBbtRepository(db, now: () => DateTime(2026, 8, 1));
  });
  tearDown(() => db.close());

  Future<List<BbtEntry>> allEntries() => repo.watchAll().first;

  test('maps in-cycle readings to 1-based cycle days, sorted', () async {
    final cycle = Cycle(
      periodStart: DateTime(2026, 7, 1),
      nextPeriodStart: DateTime(2026, 7, 29),
    );
    await repo.setTemp(DateTime(2026, 7, 1), 36.4); // day 1
    await repo.setTemp(DateTime(2026, 7, 15), 36.9); // day 15
    await repo.setTemp(DateTime(2026, 7, 6), 36.5); // day 6

    final points = bbtChartForCycle(cycle, await allEntries());
    expect(points.map((p) => p.cycleDay), [1, 6, 15]);
    expect(points.first.celsius, 36.4);
    expect(points[1].date, DateTime(2026, 7, 6));
  });

  test('drops readings before the cycle start or after its end', () async {
    final cycle = Cycle(
      periodStart: DateTime(2026, 7, 1),
      nextPeriodStart: DateTime(2026, 7, 29),
    );
    await repo.setTemp(DateTime(2026, 6, 28), 36.2); // previous cycle
    await repo.setTemp(DateTime(2026, 7, 10), 36.6); // in cycle
    await repo.setTemp(DateTime(2026, 7, 29), 36.3); // next cycle's day 1

    final points = bbtChartForCycle(cycle, await allEntries());
    expect(points, hasLength(1));
    expect(points.single.date, DateTime(2026, 7, 10));
    expect(points.single.cycleDay, 10);
  });

  test(
    'a current (open) cycle keeps every reading on or after its start',
    () async {
      final cycle = Cycle(periodStart: DateTime(2026, 7, 20)); // no next start
      await repo.setTemp(DateTime(2026, 7, 19), 36.1); // before → dropped
      await repo.setTemp(DateTime(2026, 7, 20), 36.4);
      await repo.setTemp(DateTime(2026, 8, 5), 36.8);

      final points = bbtChartForCycle(cycle, await allEntries());
      expect(points.map((p) => p.cycleDay), [1, 17]);
    },
  );

  test('an empty history yields no points', () async {
    final cycle = Cycle(periodStart: DateTime(2026, 7, 1));
    expect(bbtChartForCycle(cycle, await allEntries()), isEmpty);
  });
}
