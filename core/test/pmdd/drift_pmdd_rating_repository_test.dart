import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

/// p7.6 — the PMDD daily-rating repository. One row per `(date, item)`; a
/// [SymptomSeverity.none] rating is a real stored row ("rated, nothing today"),
/// unlike every other symptom table. [DriftPmddRatingRepository.rateDay] is a
/// per-item upsert that also drops rows for items left out this time.
void main() {
  late AppDatabase db;
  late DriftPmddRatingRepository repo;

  final now = DateTime(2026, 8, 28, 21, 30);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftPmddRatingRepository(db, now: () => now);
  });
  tearDown(() => db.close());

  test('rateDay writes one date-only row per item, stamped with now', () async {
    await repo.rateDay(DateTime(2026, 8, 20, 19, 15), {
      PmddSymptom.irritability: SymptomSeverity.severe,
      PmddSymptom.anxiety: SymptomSeverity.moderate,
    });

    final rows = await repo.allEntries();
    expect(rows, hasLength(2));
    expect(rows.every((r) => r.date == DateTime(2026, 8, 20)), isTrue);
    expect(rows.every((r) => r.createdAt == now && r.updatedAt == now), isTrue);

    final ratings = await repo.ratingsOn(DateTime(2026, 8, 20));
    expect(ratings, {
      PmddSymptom.irritability: SymptomSeverity.severe,
      PmddSymptom.anxiety: SymptomSeverity.moderate,
    });
  });

  test('a none rating is stored, not skipped', () async {
    await repo.rateDay(DateTime(2026, 8, 20), {
      PmddSymptom.bloating: SymptomSeverity.none,
      PmddSymptom.fatigue: SymptomSeverity.none,
    });

    final ratings = await repo.ratingsOn(DateTime(2026, 8, 20));
    expect(ratings, {
      PmddSymptom.bloating: SymptomSeverity.none,
      PmddSymptom.fatigue: SymptomSeverity.none,
    });
    expect(await repo.allEntries(), hasLength(2));
  });

  test(
    'rateDay upserts a changed item, preserving created_at and bumping updated_at',
    () async {
      await repo.rateDay(DateTime(2026, 8, 20), {
        PmddSymptom.irritability: SymptomSeverity.mild,
      });

      final later = DateTime(2026, 8, 21, 8);
      repo = DriftPmddRatingRepository(db, now: () => later);
      await repo.rateDay(DateTime(2026, 8, 20), {
        PmddSymptom.irritability: SymptomSeverity.severe,
      });

      final row = (await repo.allEntries()).single;
      expect(row.rating, SymptomSeverity.severe);
      expect(row.createdAt, now); // preserved
      expect(row.updatedAt, later); // bumped
    },
  );

  test('an unchanged item is left completely alone on re-rate', () async {
    await repo.rateDay(DateTime(2026, 8, 20), {
      PmddSymptom.irritability: SymptomSeverity.moderate,
    });

    final later = DateTime(2026, 8, 21, 8);
    repo = DriftPmddRatingRepository(db, now: () => later);
    await repo.rateDay(DateTime(2026, 8, 20), {
      PmddSymptom.irritability: SymptomSeverity.moderate,
    });

    final row = (await repo.allEntries()).single;
    expect(row.updatedAt, now); // not bumped — nothing changed
  });

  test('rateDay drops rows for items omitted the second time', () async {
    await repo.rateDay(DateTime(2026, 8, 20), {
      PmddSymptom.irritability: SymptomSeverity.severe,
      PmddSymptom.anxiety: SymptomSeverity.moderate,
      PmddSymptom.bloating: SymptomSeverity.none,
    });

    await repo.rateDay(DateTime(2026, 8, 20), {
      PmddSymptom.irritability: SymptomSeverity.mild,
    });

    final ratings = await repo.ratingsOn(DateTime(2026, 8, 20));
    expect(ratings, {PmddSymptom.irritability: SymptomSeverity.mild});
  });

  test('an empty map clears the day', () async {
    await repo.rateDay(DateTime(2026, 8, 20), {
      PmddSymptom.irritability: SymptomSeverity.severe,
    });
    await repo.rateDay(DateTime(2026, 8, 20), const {});

    expect(await repo.ratingsOn(DateTime(2026, 8, 20)), isEmpty);
  });

  test('clearDay removes only the given day', () async {
    await repo.rateDay(DateTime(2026, 8, 20), {
      PmddSymptom.irritability: SymptomSeverity.severe,
    });
    await repo.rateDay(DateTime(2026, 8, 21), {
      PmddSymptom.lowMood: SymptomSeverity.moderate,
    });

    await repo.clearDay(DateTime(2026, 8, 20, 12));

    expect(await repo.ratingsOn(DateTime(2026, 8, 20)), isEmpty);
    expect(await repo.ratingsOn(DateTime(2026, 8, 21)), {
      PmddSymptom.lowMood: SymptomSeverity.moderate,
    });
  });

  test(
    'days are independent — one day\'s re-rate leaves the other intact',
    () async {
      await repo.rateDay(DateTime(2026, 8, 20), {
        PmddSymptom.irritability: SymptomSeverity.severe,
        PmddSymptom.anxiety: SymptomSeverity.moderate,
      });
      await repo.rateDay(DateTime(2026, 8, 21), {
        PmddSymptom.fatigue: SymptomSeverity.mild,
      });

      await repo.rateDay(DateTime(2026, 8, 20), {
        PmddSymptom.irritability: SymptomSeverity.mild,
      });

      expect(await repo.ratingsOn(DateTime(2026, 8, 21)), {
        PmddSymptom.fatigue: SymptomSeverity.mild,
      });
    },
  );

  test('watchAll emits newest-first and updates on write', () async {
    final seen = <int>[];
    final sub = repo.watchAll().listen((rows) => seen.add(rows.length));
    await Future<void>.delayed(Duration.zero);

    await repo.rateDay(DateTime(2026, 8, 20), {
      PmddSymptom.irritability: SymptomSeverity.severe,
    });
    await Future<void>.delayed(Duration.zero);
    await repo.rateDay(DateTime(2026, 8, 22), {
      PmddSymptom.lowMood: SymptomSeverity.moderate,
    });
    await Future<void>.delayed(Duration.zero);

    final rows = await repo.allEntries();
    expect(rows.first.date, DateTime(2026, 8, 22)); // newest first
    expect(seen.last, 2);

    await sub.cancel();
  });
}
