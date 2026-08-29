import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase source;

  setUp(() => source = AppDatabase(NativeDatabase.memory()));
  tearDown(() => source.close());

  Future<void> seedEveryTable(AppDatabase db) async {
    await db
        .into(db.cycleEvents)
        .insert(
          CycleEventsCompanion.insert(
            type: CycleEventType.periodStart,
            date: DateTime.utc(2026, 1, 2),
          ),
        );
    await db
        .into(db.periods)
        .insert(
          PeriodsCompanion.insert(
            startDate: DateTime.utc(2026, 1, 2),
            endDate: Value(DateTime.utc(2026, 1, 6)),
          ),
        );
    await db
        .into(db.dailyFlows)
        .insert(
          DailyFlowsCompanion.insert(
            date: DateTime.utc(2026, 1, 3),
            intensity: FlowIntensity.medium,
            clotSize: const Value(ClotSize.small),
          ),
        );
    // A user-added symptom on top of the 11 seeded built-ins.
    final symptomId = await db
        .into(db.symptomTypes)
        .insert(SymptomTypesCompanion.insert(name: 'Cravings', sortOrder: 99));
    await db
        .into(db.dailySymptomEntries)
        .insert(
          DailySymptomEntriesCompanion.insert(
            date: DateTime.utc(2026, 1, 3),
            symptomTypeId: symptomId,
          ),
        );
    await db
        .into(db.bbtEntries)
        .insert(
          BbtEntriesCompanion.insert(
            date: DateTime.utc(2026, 1, 3),
            tempCelsius: 36.62,
          ),
        );
    await db
        .into(db.cervicalMucusEntries)
        .insert(
          CervicalMucusEntriesCompanion.insert(
            date: DateTime.utc(2026, 1, 3),
            type: CervicalMucusType.eggWhite,
          ),
        );
    await db
        .into(db.appSettings)
        .insert(AppSettingsCompanion.insert(key: 'theme_mode', value: 'dark'));
    await db
        .into(db.medications)
        .insert(
          MedicationsCompanion.insert(
            name: 'Iron',
            dosage: const Value('65 mg'),
          ),
        );
    await db
        .into(db.birthControlEntries)
        .insert(
          BirthControlEntriesCompanion.insert(
            method: BirthControlMethod.iud,
            startedOn: DateTime.utc(2025, 6, 1),
          ),
        );
    await db
        .into(db.reminders)
        .insert(
          RemindersCompanion.insert(
            kind: ReminderKind.medication,
            hour: 9,
            minute: 15,
            enabled: const Value(true),
          ),
        );
  }

  test(
    'tableOrder covers exactly the schema (fails loudly on a new table)',
    () {
      expect(
        BackupService.tableOrder.toSet(),
        source.allTables.map((t) => t.actualTableName).toSet(),
      );
    },
  );

  test('export → fresh db → import reproduces every table exactly', () async {
    await seedEveryTable(source);
    final exported = await BackupService(source).export();
    expect(exported.appSchemaVersion, source.schemaVersion);
    expect(exported.tables.keys, containsAll(BackupService.tableOrder));

    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    // The fresh target already has its 11 seeded built-in symptoms and none of
    // the source's data — a real "restore onto another device" starting point.
    await BackupService(target).import(exported);

    final reExported = await BackupService(target).export();
    for (final table in BackupService.tableOrder) {
      expect(
        reExported.tables[table],
        exported.tables[table],
        reason: 'table "$table" differs after restore',
      );
    }
  });

  test('import replaces existing data rather than merging it', () async {
    await seedEveryTable(source);
    final backup = await BackupService(source).export();

    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    await target
        .into(target.periods)
        .insert(PeriodsCompanion.insert(startDate: DateTime.utc(2020, 1, 1)));
    await target
        .into(target.appSettings)
        .insert(AppSettingsCompanion.insert(key: 'stale', value: 'value'));

    await BackupService(target).import(backup);

    final periods = await target.select(target.periods).get();
    expect(periods, hasLength(1));
    expect(periods.single.startDate.toUtc(), DateTime.utc(2026, 1, 2));
    final settings = await target.select(target.appSettings).get();
    expect(settings.map((s) => s.key), ['theme_mode']);
  });

  test('a schema-version mismatch is refused', () async {
    final backup = await BackupService(source).export();
    final wrongSchema = BackupDocument(
      formatVersion: backup.formatVersion,
      appSchemaVersion: backup.appSchemaVersion + 1,
      createdAt: backup.createdAt,
      tables: backup.tables,
    );
    expect(
      () => BackupService(source).import(wrongSchema),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('a failing insert rolls the whole restore back', () async {
    await seedEveryTable(source);
    final backup = await BackupService(source).export();
    // Corrupt one row so its INSERT throws mid-transaction.
    backup.tables['periods']!.add({'no_such_column': 1});

    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    await expectLater(BackupService(target).import(backup), throwsA(anything));

    // The wipe was part of the same transaction, so the built-in symptoms the
    // fresh db seeded are still there — nothing was committed.
    final symptoms = await target.select(target.symptomTypes).get();
    expect(symptoms, hasLength(kBuiltInSymptomNames.length));
  });
}
