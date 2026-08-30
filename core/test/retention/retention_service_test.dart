import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  // A window whose cutoff is a fixed date, independent of the wall clock.
  const window = RetentionWindow.year1;
  final now = DateTime(2026, 8, 15);
  final cutoff = window.cutoff(now)!; // 2025-08-15
  final old = cutoff.subtract(const Duration(days: 1)); // 2025-08-14 — purged
  final fresh = cutoff.add(const Duration(days: 1)); // 2025-08-16 — kept

  Future<int> count(TableInfo<Table, dynamic> t) async =>
      (await db.select(t).get()).length;

  test('deleteWhere partitions the schema into dated and config tables', () {
    const config = {
      'medications',
      'symptom_types',
      'reminders',
      'app_settings',
    };
    final all = db.allTables.map((t) => t.actualTableName).toSet();
    expect(
      RetentionService.deleteWhere.keys.toSet().union(config),
      all,
      reason:
          'a new table must be added to RetentionService.deleteWhere '
          '(dated) or to the config set in this test (never purged)',
    );
    expect(
      RetentionService.deleteWhere.keys.toSet().intersection(config),
      isEmpty,
    );
  });

  test('off is a no-op and reports nothing', () async {
    await db
        .into(db.dailyFlows)
        .insert(
          DailyFlowsCompanion.insert(date: old, intensity: FlowIntensity.light),
        );
    final result = await RetentionService(
      db,
    ).sweep(now: now, window: RetentionWindow.off);
    expect(result.cutoff, isNull);
    expect(result.didAnything, isFalse);
    expect(result.total, 0);
    expect(await count(db.dailyFlows), 1);
  });

  test(
    'deletes entries strictly older than the cutoff, keeps the rest',
    () async {
      for (final d in [old, cutoff, fresh]) {
        await db
            .into(db.cycleEvents)
            .insert(
              CycleEventsCompanion.insert(
                type: CycleEventType.periodStart,
                date: d,
              ),
            );
        await db
            .into(db.bbtEntries)
            .insert(BbtEntriesCompanion.insert(date: d, tempCelsius: 36.5));
        await db
            .into(db.cervicalMucusEntries)
            .insert(
              CervicalMucusEntriesCompanion.insert(
                date: d,
                type: CervicalMucusType.dry,
              ),
            );
      }
      final symptomId = await db
          .into(db.symptomTypes)
          .insert(
            SymptomTypesCompanion.insert(name: 'Cravings', sortOrder: 99),
          );
      for (final d in [old, cutoff, fresh]) {
        await db
            .into(db.dailySymptomEntries)
            .insert(
              DailySymptomEntriesCompanion.insert(
                date: d,
                symptomTypeId: symptomId,
              ),
            );
      }

      final result = await RetentionService(db).sweep(now: now, window: window);

      expect(result.cutoff, cutoff);
      expect(result.total, 4);
      expect(result.deletedByTable, {
        'cycle_events': 1,
        'bbt_entries': 1,
        'cervical_mucus_entries': 1,
        'daily_symptom_entries': 1,
      });
      // The cutoff day itself and everything after it stay.
      expect(await count(db.cycleEvents), 2);
      expect(await count(db.bbtEntries), 2);
      expect(await count(db.cervicalMucusEntries), 2);
      expect(await count(db.dailySymptomEntries), 2);
      // The catalogue row is untouched.
      expect(await count(db.symptomTypes), kBuiltInSymptomNames.length + 1);
    },
  );

  test(
    'a period is kept while any part of it is on or after the cutoff',
    () async {
      // Fully before — purged.
      await db
          .into(db.periods)
          .insert(
            PeriodsCompanion.insert(
              startDate: DateTime(2025, 1, 1),
              endDate: Value(DateTime(2025, 1, 5)),
            ),
          );
      // Straddles the cutoff — kept.
      await db
          .into(db.periods)
          .insert(
            PeriodsCompanion.insert(startDate: old, endDate: Value(fresh)),
          );
      // Open-ended and recent — kept.
      await db
          .into(db.periods)
          .insert(PeriodsCompanion.insert(startDate: fresh));

      final result = await RetentionService(db).sweep(now: now, window: window);

      expect(result.deletedByTable['periods'], 1);
      final kept = await db.select(db.periods).get();
      expect(kept.map((p) => p.startDate), unorderedEquals([old, fresh]));
    },
  );

  test(
    'an open-ended period is purged only when its start is past the cutoff',
    () async {
      await db.into(db.periods).insert(PeriodsCompanion.insert(startDate: old));
      final result = await RetentionService(db).sweep(now: now, window: window);
      expect(result.deletedByTable['periods'], 1);
      expect(await count(db.periods), 0);
    },
  );

  test('birth control: a current method is always kept; an ended one is '
      'purged once it ended before the cutoff', () async {
    // Current (ended_on IS NULL), started years ago — kept.
    await db
        .into(db.birthControlEntries)
        .insert(
          BirthControlEntriesCompanion.insert(
            method: BirthControlMethod.iud,
            startedOn: DateTime(2020, 1, 1),
          ),
        );
    // Ended before the cutoff — purged.
    await db
        .into(db.birthControlEntries)
        .insert(
          BirthControlEntriesCompanion.insert(
            method: BirthControlMethod.pill,
            startedOn: DateTime(2019, 1, 1),
            endedOn: Value(old),
          ),
        );
    // Ended after the cutoff — kept.
    await db
        .into(db.birthControlEntries)
        .insert(
          BirthControlEntriesCompanion.insert(
            method: BirthControlMethod.patch,
            startedOn: DateTime(2019, 1, 1),
            endedOn: Value(fresh),
          ),
        );

    final result = await RetentionService(db).sweep(now: now, window: window);

    expect(result.deletedByTable['birth_control_entries'], 1);
    final kept = await db.select(db.birthControlEntries).get();
    expect(
      kept.map((e) => e.method),
      unorderedEquals([BirthControlMethod.iud, BirthControlMethod.patch]),
    );
  });

  test('a fully clean sweep reports zero and no per-table entries', () async {
    await db
        .into(db.dailyFlows)
        .insert(
          DailyFlowsCompanion.insert(
            date: fresh,
            intensity: FlowIntensity.light,
          ),
        );
    final result = await RetentionService(db).sweep(now: now, window: window);
    expect(result.cutoff, cutoff);
    expect(result.didAnything, isFalse);
    expect(result.deletedByTable, isEmpty);
    expect(await count(db.dailyFlows), 1);
  });
}
