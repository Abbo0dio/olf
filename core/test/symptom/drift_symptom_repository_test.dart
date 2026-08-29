import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftSymptomRepository repo;

  final now = DateTime(2026, 8, 28, 9, 30);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftSymptomRepository(db, now: () => now);
  });
  tearDown(() => db.close());

  group('catalogue', () {
    test(
      'a fresh database is seeded with the built-in names in order',
      () async {
        final types = await repo.activeTypes();
        expect(types.map((t) => t.name), kBuiltInSymptomNames);
        expect(types.every((t) => t.isBuiltIn), isTrue);
        expect(types.map((t) => t.sortOrder), [
          for (var i = 0; i < kBuiltInSymptomNames.length; i++) i,
        ]);
      },
    );

    test('addType appends a custom symptom after the last sortOrder', () async {
      final created = await repo.addType('  Cravings  ');
      expect(created.name, 'Cravings');
      expect(created.isBuiltIn, isFalse);
      expect(created.createdAt, now);

      final types = await repo.activeTypes();
      expect(types.last.name, 'Cravings');
      expect(types.last.sortOrder, kBuiltInSymptomNames.length);
    });

    test('addType rejects an empty or duplicate name', () async {
      await expectLater(
        repo.addType('   '),
        throwsA(
          isA<SymptomTypeException>().having(
            (e) => e.error,
            'error',
            SymptomTypeError.empty,
          ),
        ),
      );
      await expectLater(
        repo.addType('cramps'),
        throwsA(
          isA<SymptomTypeException>().having(
            (e) => e.error,
            'error',
            SymptomTypeError.duplicate,
          ),
        ),
      );
    });

    test('renameType changes the name and allows a pure case change', () async {
      final types = await repo.activeTypes();
      final cramps = types.firstWhere((t) => t.name == 'Cramps');

      await repo.renameType(cramps.id, 'CRAMPS');
      final after = await repo.activeTypes();
      expect(after.firstWhere((t) => t.id == cramps.id).name, 'CRAMPS');
    });

    test('renameType rejects colliding with a different active name', () async {
      final types = await repo.activeTypes();
      final cramps = types.firstWhere((t) => t.name == 'Cramps');
      await expectLater(
        repo.renameType(cramps.id, 'Bloating'),
        throwsA(isA<SymptomTypeException>()),
      );
    });

    test('reorderTypes rewrites sortOrder to list position', () async {
      final before = await repo.activeTypes();
      final reversed = before.reversed.map((t) => t.id).toList();

      await repo.reorderTypes(reversed);

      final after = await repo.activeTypes();
      expect(after.map((t) => t.id), reversed);
      expect(after.map((t) => t.name), before.reversed.map((t) => t.name));
    });

    test('archiveType hides the symptom but keeps its entries', () async {
      final types = await repo.activeTypes();
      final acne = types.firstWhere((t) => t.name == 'Acne');
      await repo.setSymptom(DateTime(2026, 8, 20), acne.id, present: true);

      await repo.archiveType(acne.id);

      final active = await repo.activeTypes();
      expect(active.any((t) => t.id == acne.id), isFalse);

      final entries = await repo.watchAllEntries().first;
      expect(entries.single.symptomTypeId, acne.id);
    });

    test('an archived name can be reused for a new custom symptom', () async {
      final types = await repo.activeTypes();
      final acne = types.firstWhere((t) => t.name == 'Acne');
      await repo.archiveType(acne.id);

      final recreated = await repo.addType('Acne');
      expect(recreated.id, isNot(acne.id));
    });

    test('watchTypes re-emits on add and archive', () async {
      final counts = <int>[];
      final sub = repo.watchTypes().listen((rows) => counts.add(rows.length));
      await pumpEventQueue();

      final created = await repo.addType('Cravings');
      await pumpEventQueue();
      await repo.archiveType(created.id);
      await pumpEventQueue();

      await sub.cancel();
      final n = kBuiltInSymptomNames.length;
      expect(counts, [n, n + 1, n]);
    });
  });

  group('day logging', () {
    test('setSymptom present then absent toggles a single row', () async {
      final types = await repo.activeTypes();
      final a = types[0].id;
      final b = types[1].id;
      final day = DateTime(2026, 8, 20, 22, 15);

      await repo.setSymptom(day, a, present: true);
      await repo.setSymptom(day, b, present: true);
      expect(await repo.symptomsOn(DateTime(2026, 8, 20)), {a, b});

      await repo.setSymptom(day, a, present: false);
      expect(await repo.symptomsOn(DateTime(2026, 8, 20)), {b});
    });

    test('setSymptom present is idempotent (no duplicate-key crash)', () async {
      final id = (await repo.activeTypes()).first.id;
      await repo.setSymptom(DateTime(2026, 8, 20), id, present: true);
      await repo.setSymptom(DateTime(2026, 8, 20), id, present: true);
      final entries = await repo.watchAllEntries().first;
      expect(entries, hasLength(1));
    });

    test('setSymptom absent on an unlogged day is a no-op', () async {
      final id = (await repo.activeTypes()).first.id;
      await repo.setSymptom(DateTime(2026, 1, 1), id, present: false);
      expect(await repo.symptomsOn(DateTime(2026, 1, 1)), isEmpty);
    });

    test('symptomsOn is date-only (ignores time of day)', () async {
      final id = (await repo.activeTypes()).first.id;
      await repo.setSymptom(DateTime(2026, 8, 20, 23, 59), id, present: true);
      expect(await repo.symptomsOn(DateTime(2026, 8, 20, 1)), {id});
    });

    test('clearDay removes only that day', () async {
      final id = (await repo.activeTypes()).first.id;
      await repo.setSymptom(DateTime(2026, 8, 20), id, present: true);
      await repo.setSymptom(DateTime(2026, 8, 21), id, present: true);

      await repo.clearDay(DateTime(2026, 8, 20));

      expect(await repo.symptomsOn(DateTime(2026, 8, 20)), isEmpty);
      expect(await repo.symptomsOn(DateTime(2026, 8, 21)), {id});
    });

    test('watchAllEntries emits newest day first', () async {
      final id = (await repo.activeTypes()).first.id;
      await repo.setSymptom(DateTime(2026, 8, 10), id, present: true);
      await repo.setSymptom(DateTime(2026, 8, 25), id, present: true);
      await repo.setSymptom(DateTime(2026, 8, 15), id, present: true);

      final entries = await repo.watchAllEntries().first;
      expect(entries.map((e) => e.date), [
        DateTime(2026, 8, 25),
        DateTime(2026, 8, 15),
        DateTime(2026, 8, 10),
      ]);
    });

    test('is independent of periods (no cascade)', () async {
      final periods = DriftPeriodRepository(db, now: () => now);
      final id = await periods.addPeriod(
        PeriodDraft(start: DateTime(2026, 8, 18), end: DateTime(2026, 8, 22)),
      );
      final typeId = (await repo.activeTypes()).first.id;
      await repo.setSymptom(DateTime(2026, 8, 20), typeId, present: true);

      await periods.deletePeriod(id);

      expect(await repo.symptomsOn(DateTime(2026, 8, 20)), {typeId});
    });
  });
}
