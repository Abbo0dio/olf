import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftBbtRepository repo;

  final now = DateTime(2026, 8, 28, 6, 30);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftBbtRepository(db, now: () => now);
  });
  tearDown(() => db.close());

  test('setTemp stores a date-only row in Celsius', () async {
    await repo.setTemp(DateTime(2026, 8, 20, 6, 15), 36.55);

    final row = await repo.tempOn(DateTime(2026, 8, 20));
    expect(row, isNotNull);
    expect(row!.date, DateTime(2026, 8, 20));
    expect(row.tempCelsius, 36.55);
    expect(row.createdAt, now);
    expect(row.updatedAt, now);
  });

  test('setTemp upserts and preserves created_at, bumps updated_at', () async {
    await repo.setTemp(DateTime(2026, 8, 20), 36.4);

    final later = DateTime(2026, 8, 21, 7);
    repo = DriftBbtRepository(db, now: () => later);
    await repo.setTemp(DateTime(2026, 8, 20), 36.9);

    final rows = await repo.watchAll().first;
    expect(rows, hasLength(1));
    expect(rows.single.tempCelsius, 36.9);
    expect(rows.single.createdAt, now);
    expect(rows.single.updatedAt, later);
  });

  test('setTemp rejects an implausible reading and writes nothing', () async {
    await expectLater(
      repo.setTemp(DateTime(2026, 8, 20), 98.6),
      throwsA(
        isA<BbtException>().having((e) => e.error, 'error', BbtError.tooHigh),
      ),
    );
    expect(await repo.tempOn(DateTime(2026, 8, 20)), isNull);
  });

  test('clearTemp removes the day; a missing day is a no-op', () async {
    await repo.setTemp(DateTime(2026, 8, 20), 36.6);
    await repo.clearTemp(DateTime(2026, 8, 19));
    expect(await repo.tempOn(DateTime(2026, 8, 20)), isNotNull);
    await repo.clearTemp(DateTime(2026, 8, 20));
    expect(await repo.tempOn(DateTime(2026, 8, 20)), isNull);
  });

  test('watchAll emits newest day first', () async {
    await repo.setTemp(DateTime(2026, 8, 10), 36.3);
    await repo.setTemp(DateTime(2026, 8, 25), 36.8);
    await repo.setTemp(DateTime(2026, 8, 15), 36.5);

    final rows = await repo.watchAll().first;
    expect(rows.map((r) => r.date), [
      DateTime(2026, 8, 25),
      DateTime(2026, 8, 15),
      DateTime(2026, 8, 10),
    ]);
  });

  test('setTemp defaults provenance to manual with no external id', () async {
    await repo.setTemp(DateTime(2026, 8, 20), 36.6);
    final row = (await repo.tempOn(DateTime(2026, 8, 20)))!;
    expect(row.source, 'manual');
    expect(row.externalId, isNull);
  });

  test('setTemp defaults measurementKind to basal (p8.1a)', () async {
    await repo.setTemp(DateTime(2026, 8, 20), 36.6);
    final row = (await repo.tempOn(DateTime(2026, 8, 20)))!;
    expect(row.measurementKind, BbtMeasurementKind.basal);
  });

  test('setTemp round-trips a sleepingWrist reading (p8.1a)', () async {
    await repo.setTemp(
      DateTime(2026, 8, 20),
      36.95,
      source: HealthDataSource.appleHealth,
      externalId: 'HK-wrist-1',
      measurementKind: BbtMeasurementKind.sleepingWrist,
    );
    final row = (await repo.tempOn(DateTime(2026, 8, 20)))!;
    expect(row.measurementKind, BbtMeasurementKind.sleepingWrist);
    expect(row.source, 'appleHealth');
    expect(row.externalId, 'HK-wrist-1');
  });

  test(
    'editing a sleepingWrist row (no kind passed) resets it to basal — a '
    'corrected passive reading becomes a typed basal temperature (p8.1a)',
    () async {
      await repo.setTemp(
        DateTime(2026, 8, 20),
        36.95,
        source: HealthDataSource.appleHealth,
        externalId: 'HK-wrist-2',
        measurementKind: BbtMeasurementKind.sleepingWrist,
      );

      // A plain in-app edit — no kind / source args.
      await repo.setTemp(DateTime(2026, 8, 20), 36.60);

      final row = (await repo.tempOn(DateTime(2026, 8, 20)))!;
      expect(row.measurementKind, BbtMeasurementKind.basal);
      expect(row.source, 'manual');
      expect(row.externalId, 'HK-wrist-2'); // still sticky for write-back
      expect(row.tempCelsius, 36.60);
    },
  );

  test('setTemp records an imported source and external id (p6.2)', () async {
    await repo.setTemp(
      DateTime(2026, 8, 20),
      36.72,
      source: HealthDataSource.appleHealth,
      externalId: 'HK-bbt-1',
    );
    final row = (await repo.tempOn(DateTime(2026, 8, 20)))!;
    expect(row.source, 'appleHealth');
    expect(row.externalId, 'HK-bbt-1');
  });

  test('setTemp upsert can flip a manual row to imported provenance', () async {
    await repo.setTemp(DateTime(2026, 8, 20), 36.4);
    await repo.setTemp(
      DateTime(2026, 8, 20),
      36.9,
      source: HealthDataSource.appleHealth,
      externalId: 'HK-bbt-2',
    );
    final row = (await repo.tempOn(DateTime(2026, 8, 20)))!;
    expect(row.source, 'appleHealth');
    expect(row.externalId, 'HK-bbt-2');
    expect(row.tempCelsius, 36.9);
  });

  test(
    'editing an imported row (no id passed) flips it to manual but keeps the '
    'external id — the p6.4 write-back link survives the edit',
    () async {
      await repo.setTemp(
        DateTime(2026, 8, 20),
        36.4,
        source: HealthDataSource.appleHealth,
        externalId: 'HK-bbt-3',
      );

      // A plain in-app edit — no source / externalId args.
      await repo.setTemp(DateTime(2026, 8, 20), 36.72);

      final row = (await repo.tempOn(DateTime(2026, 8, 20)))!;
      expect(row.source, 'manual');
      expect(row.externalId, 'HK-bbt-3');
      expect(row.tempCelsius, 36.72);
    },
  );

  test('allEntries returns a one-shot snapshot, newest day first', () async {
    await repo.setTemp(DateTime(2026, 8, 10), 36.3);
    await repo.setTemp(DateTime(2026, 8, 25), 36.8);
    await repo.setTemp(DateTime(2026, 8, 15), 36.5);

    final rows = await repo.allEntries();
    expect(rows.map((r) => r.date), [
      DateTime(2026, 8, 25),
      DateTime(2026, 8, 15),
      DateTime(2026, 8, 10),
    ]);
  });

  test('BBT is independent of periods (no cascade)', () async {
    final periods = DriftPeriodRepository(db, now: () => now);
    final id = await periods.addPeriod(
      PeriodDraft(start: DateTime(2026, 8, 18), end: DateTime(2026, 8, 22)),
    );
    await repo.setTemp(DateTime(2026, 8, 20), 36.7);

    await periods.deletePeriod(id);

    expect((await repo.tempOn(DateTime(2026, 8, 20)))!.tempCelsius, 36.7);
  });
}
