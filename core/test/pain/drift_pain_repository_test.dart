import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftPainRepository repo;

  final now = DateTime(2026, 8, 28, 21, 30);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftPainRepository(db, now: () => now);
  });
  tearDown(() => db.close());

  test('setPain stores a date-only row with every field', () async {
    await repo.setPain(
      DateTime(2026, 8, 20, 19, 15),
      intensity: SymptomSeverity.moderate,
      region: PainRegion.pelvic,
      note: 'worse walking',
      isFlare: true,
    );

    final row = await repo.painOn(DateTime(2026, 8, 20));
    expect(row, isNotNull);
    expect(row!.date, DateTime(2026, 8, 20));
    expect(row.intensity, SymptomSeverity.moderate);
    expect(row.region, PainRegion.pelvic);
    expect(row.note, 'worse walking');
    expect(row.isFlare, isTrue);
    expect(row.createdAt, now);
    expect(row.updatedAt, now);
  });

  test('region and note are optional', () async {
    await repo.setPain(DateTime(2026, 8, 21), intensity: SymptomSeverity.mild);
    final row = await repo.painOn(DateTime(2026, 8, 21));
    expect(row!.region, isNull);
    expect(row.note, isNull);
    expect(row.isFlare, isFalse);
  });

  test(
    'setPain upserts, preserving created_at and bumping updated_at',
    () async {
      await repo.setPain(
        DateTime(2026, 8, 20),
        intensity: SymptomSeverity.mild,
      );

      final later = DateTime(2026, 8, 21, 8);
      repo = DriftPainRepository(db, now: () => later);
      await repo.setPain(
        DateTime(2026, 8, 20),
        intensity: SymptomSeverity.severe,
        isFlare: true,
      );

      final rows = await repo.watchAll().first;
      expect(rows, hasLength(1));
      expect(rows.single.intensity, SymptomSeverity.severe);
      expect(rows.single.isFlare, isTrue);
      expect(rows.single.createdAt, now);
      expect(rows.single.updatedAt, later);
    },
  );

  test('a cleared field on re-set goes back to null', () async {
    await repo.setPain(
      DateTime(2026, 8, 20),
      intensity: SymptomSeverity.moderate,
      region: PainRegion.legs,
      note: 'typed something',
    );
    await repo.setPain(DateTime(2026, 8, 20), intensity: SymptomSeverity.mild);
    final row = await repo.painOn(DateTime(2026, 8, 20));
    expect(row!.region, isNull);
    expect(row.note, isNull);
  });

  test('note is trimmed; blank becomes null', () async {
    await repo.setPain(
      DateTime(2026, 8, 20),
      intensity: SymptomSeverity.mild,
      note: '  spotting too  ',
    );
    expect((await repo.painOn(DateTime(2026, 8, 20)))!.note, 'spotting too');

    await repo.setPain(
      DateTime(2026, 8, 21),
      intensity: SymptomSeverity.mild,
      note: '   ',
    );
    expect((await repo.painOn(DateTime(2026, 8, 21)))!.note, isNull);
  });

  test('setPain rejects SymptomSeverity.none', () async {
    expect(
      () =>
          repo.setPain(DateTime(2026, 8, 20), intensity: SymptomSeverity.none),
      throwsA(isA<PainException>()),
    );
    expect(await repo.painOn(DateTime(2026, 8, 20)), isNull);
  });

  test('setPain rejects an over-long note', () async {
    expect(
      () => repo.setPain(
        DateTime(2026, 8, 20),
        intensity: SymptomSeverity.mild,
        note: 'x' * (kPainNoteMaxLength + 1),
      ),
      throwsA(isA<PainException>()),
    );
  });

  test('clearDay removes the row and is a no-op when absent', () async {
    await repo.setPain(DateTime(2026, 8, 20), intensity: SymptomSeverity.mild);
    await repo.clearDay(DateTime(2026, 8, 20));
    expect(await repo.painOn(DateTime(2026, 8, 20)), isNull);
    await repo.clearDay(DateTime(2026, 8, 20)); // no throw
  });

  test('watchAll is newest-day first', () async {
    await repo.setPain(DateTime(2026, 8, 10), intensity: SymptomSeverity.mild);
    await repo.setPain(
      DateTime(2026, 8, 20),
      intensity: SymptomSeverity.severe,
    );
    await repo.setPain(
      DateTime(2026, 8, 15),
      intensity: SymptomSeverity.moderate,
    );

    final rows = await repo.watchAll().first;
    expect(rows.map((r) => r.date), [
      DateTime(2026, 8, 20),
      DateTime(2026, 8, 15),
      DateTime(2026, 8, 10),
    ]);
  });
}
