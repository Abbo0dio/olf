import '../db/app_database.dart';
import '../db/tables.dart';
import '../symptom/symptom_severity.dart';

/// Reads and writes the PMDD daily-rating log ([PmddRating]) — one row per
/// `(date, item)` (schema v9, p7.6).
///
/// Unlike the pain log, [SymptomSeverity.none] is a **valid stored rating**
/// here: a PMDD rating is filled in every day it is opened, and "rated, nothing
/// today" is a real data point. A day is removed only by an explicit
/// [clearDay]; [rateDay] with an empty map does the same.
abstract interface class PmddRatingRepository {
  /// The ratings logged for [date], keyed by item. Empty if that day has none.
  Future<Map<PmddSymptom, SymptomSeverity>> ratingsOn(DateTime date);

  /// Every logged rating row as a stream that re-emits on any change, newest
  /// day first.
  Stream<List<PmddRating>> watchAll();

  /// Every logged rating row, newest day first, as a one-shot read.
  Future<List<PmddRating>> allEntries();

  /// Record (or replace) [date]'s ratings. Upserts one row per entry in
  /// [ratings] (`none` included), preserving `created_at` on rows that already
  /// exist, and deletes any existing row for [date] whose item is **not** in
  /// [ratings]. An empty [ratings] map clears the day.
  Future<void> rateDay(
    DateTime date,
    Map<PmddSymptom, SymptomSeverity> ratings,
  );

  /// Remove every rating logged for [date]. A no-op if that day has none.
  Future<void> clearDay(DateTime date);
}
