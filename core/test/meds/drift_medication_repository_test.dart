import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftMedicationRepository repo;
  var clock = DateTime(2026, 8, 29, 9);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftMedicationRepository(db, now: () => clock);
  });
  tearDown(() => db.close());

  test(
    'add stores name and optional fields, trimming blanks to null',
    () async {
      final med = await repo.add('  Iron  ', dosage: '  ', notes: 'with food');
      expect(med.name, 'Iron');
      expect(med.dosage, isNull);
      expect(med.notes, 'with food');
      expect(med.createdAt, clock);
    },
  );

  test('add rejects an empty name', () async {
    expect(
      () => repo.add('   '),
      throwsA(
        isA<MedicationException>().having(
          (e) => e.error,
          'error',
          MedicationError.nameEmpty,
        ),
      ),
    );
  });

  test(
    'watchActive is name-ordered, case-insensitive, and excludes archived',
    () async {
      await repo.add('zinc');
      await repo.add('Aspirin');
      final b = await repo.add('beta blocker');

      expect((await repo.activeMedications()).map((m) => m.name), [
        'Aspirin',
        'beta blocker',
        'zinc',
      ]);

      await repo.archive(b.id);
      expect((await repo.activeMedications()).map((m) => m.name), [
        'Aspirin',
        'zinc',
      ]);

      await repo.unarchive(b.id);
      expect((await repo.activeMedications()).length, 3);
    },
  );

  test('edit updates fields and bumps updatedAt', () async {
    final med = await repo.add('Iron', dosage: '50 mg');
    clock = DateTime(2026, 8, 30, 8);
    await repo.edit(med.id, name: 'Ferrous sulfate', dosage: null, notes: 'am');

    final after = (await repo.activeMedications()).single;
    expect(after.name, 'Ferrous sulfate');
    expect(after.dosage, isNull);
    expect(after.notes, 'am');
    expect(after.updatedAt, DateTime(2026, 8, 30, 8));
    expect(after.createdAt, DateTime(2026, 8, 29, 9));
  });

  test('watchActive emits on change', () async {
    final seen = <int>[];
    final sub = repo.watchActive().listen((rows) => seen.add(rows.length));
    await pumpEventQueue();
    await repo.add('Iron');
    await pumpEventQueue();
    await sub.cancel();
    expect(seen, containsAllInOrder([0, 1]));
  });
}
