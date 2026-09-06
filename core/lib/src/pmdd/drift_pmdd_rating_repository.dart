import 'package:drift/drift.dart';

import '../date_math.dart';
import '../db/app_database.dart';
import '../db/tables.dart';
import '../symptom/symptom_severity.dart';
import 'pmdd_rating_repository.dart';

/// [PmddRatingRepository] backed by the drift [AppDatabase].
class DriftPmddRatingRepository implements PmddRatingRepository {
  DriftPmddRatingRepository(this._db, {DateTime Function() now = DateTime.now})
    : _now = now;

  final AppDatabase _db;

  /// Injectable "now" — keeps the `createdAt` / `updatedAt` stamps deterministic
  /// in tests and the repository offline.
  final DateTime Function() _now;

  @override
  Future<Map<PmddSymptom, SymptomSeverity>> ratingsOn(DateTime date) async {
    final day = dateOnly(date);
    final rows = await (_db.select(
      _db.pmddRatings,
    )..where((t) => t.date.equals(day))).get();
    return {for (final r in rows) r.item: r.rating};
  }

  @override
  Stream<List<PmddRating>> watchAll() {
    return (_db.select(_db.pmddRatings)..orderBy([
          (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  @override
  Future<List<PmddRating>> allEntries() {
    return (_db.select(_db.pmddRatings)..orderBy([
          (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        ]))
        .get();
  }

  @override
  Future<void> rateDay(
    DateTime date,
    Map<PmddSymptom, SymptomSeverity> ratings,
  ) async {
    final day = dateOnly(date);
    final stamp = _now();

    await _db.transaction(() async {
      final existing = {
        for (final r in await (_db.select(
          _db.pmddRatings,
        )..where((t) => t.date.equals(day))).get())
          r.item: r,
      };

      // Drop rows for items the user did not include this time.
      for (final item in existing.keys) {
        if (ratings.containsKey(item)) continue;
        await (_db.delete(
          _db.pmddRatings,
        )..where((t) => t.date.equals(day) & t.item.equalsValue(item))).go();
      }

      for (final entry in ratings.entries) {
        final prior = existing[entry.key];
        if (prior == null) {
          await _db
              .into(_db.pmddRatings)
              .insert(
                PmddRatingsCompanion.insert(
                  date: day,
                  item: entry.key,
                  rating: entry.value,
                  createdAt: Value(stamp),
                  updatedAt: Value(stamp),
                ),
              );
        } else if (prior.rating != entry.value) {
          await (_db.update(_db.pmddRatings)..where(
                (t) => t.date.equals(day) & t.item.equalsValue(entry.key),
              ))
              .write(
                PmddRatingsCompanion(
                  rating: Value(entry.value),
                  updatedAt: Value(stamp),
                ),
              );
        }
      }
    });
  }

  @override
  Future<void> clearDay(DateTime date) async {
    final day = dateOnly(date);
    await (_db.delete(_db.pmddRatings)..where((t) => t.date.equals(day))).go();
  }
}
