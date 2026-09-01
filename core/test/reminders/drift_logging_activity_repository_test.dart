import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftLoggingActivityRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftLoggingActivityRepository(db);
  });
  tearDown(() => db.close());

  Future<void> addPeriod(DateTime createdAt) => db
      .into(db.periods)
      .insert(
        PeriodsCompanion.insert(
          startDate: DateTime(createdAt.year, createdAt.month, createdAt.day),
          createdAt: Value(createdAt),
        ),
      );

  Future<void> addFlow(DateTime date, DateTime createdAt) => db
      .into(db.dailyFlows)
      .insert(
        DailyFlowsCompanion.insert(
          date: date,
          intensity: FlowIntensity.medium,
          createdAt: Value(createdAt),
        ),
      );

  Future<void> addSymptom(DateTime date, DateTime createdAt) => db
      .into(db.dailySymptomEntries)
      .insert(
        DailySymptomEntriesCompanion.insert(
          date: date,
          symptomTypeId: 1, // a built-in symptom seeded on database creation
          createdAt: Value(createdAt),
        ),
      );

  Future<void> addBbt(DateTime date, DateTime createdAt) => db
      .into(db.bbtEntries)
      .insert(
        BbtEntriesCompanion.insert(
          date: date,
          tempCelsius: 36.5,
          createdAt: Value(createdAt),
        ),
      );

  Future<void> addMucus(DateTime date, DateTime createdAt) => db
      .into(db.cervicalMucusEntries)
      .insert(
        CervicalMucusEntriesCompanion.insert(
          date: date,
          type: CervicalMucusType.creamy,
          createdAt: Value(createdAt),
        ),
      );

  test('merges createdAt across all five tables, newest first', () async {
    await addPeriod(DateTime(2026, 6, 10, 8));
    await addFlow(DateTime(2026, 6, 11), DateTime(2026, 6, 11, 21));
    await addSymptom(DateTime(2026, 6, 12), DateTime(2026, 6, 12, 7));
    await addBbt(DateTime(2026, 6, 13), DateTime(2026, 6, 13, 6));
    await addMucus(DateTime(2026, 6, 14), DateTime(2026, 6, 14, 22));

    final stamps = await repo.recentLogTimestamps(since: DateTime(2026, 6, 1));

    expect(stamps, [
      DateTime(2026, 6, 14, 22),
      DateTime(2026, 6, 13, 6),
      DateTime(2026, 6, 12, 7),
      DateTime(2026, 6, 11, 21),
      DateTime(2026, 6, 10, 8),
    ]);
  });

  test('excludes rows created before "since"', () async {
    await addPeriod(DateTime(2026, 5, 20, 9)); // before
    await addFlow(DateTime(2026, 6, 2), DateTime(2026, 6, 2, 9)); // after
    await addBbt(DateTime(2026, 5, 31), DateTime(2026, 5, 31, 9)); // before

    final stamps = await repo.recentLogTimestamps(since: DateTime(2026, 6, 1));

    expect(stamps, [DateTime(2026, 6, 2, 9)]);
  });

  test(
    'a table with no rows contributes nothing; empty overall is empty',
    () async {
      expect(
        await repo.recentLogTimestamps(since: DateTime(2026, 6, 1)),
        isEmpty,
      );

      await addBbt(DateTime(2026, 6, 5), DateTime(2026, 6, 5, 6));
      expect(await repo.recentLogTimestamps(since: DateTime(2026, 6, 1)), [
        DateTime(2026, 6, 5, 6),
      ]);
    },
  );

  test('a "since" in the future yields nothing', () async {
    await addPeriod(DateTime(2026, 6, 10, 8));
    expect(
      await repo.recentLogTimestamps(since: DateTime(2027, 1, 1)),
      isEmpty,
    );
  });

  test('caps the result at "limit", keeping the newest', () async {
    for (var d = 1; d <= 10; d++) {
      await addBbt(DateTime(2026, 6, d), DateTime(2026, 6, d, 6));
    }

    final stamps = await repo.recentLogTimestamps(
      since: DateTime(2026, 6, 1),
      limit: 3,
    );

    expect(stamps, [
      DateTime(2026, 6, 10, 6),
      DateTime(2026, 6, 9, 6),
      DateTime(2026, 6, 8, 6),
    ]);
  });
}
