import '../db/app_database.dart';

/// Reads and writes per-day basal body temperature ([BbtEntry]).
///
/// One row per calendar day, stored in **degrees Celsius**. The only rule is
/// plausibility (`validateCelsius`), enforced in [setTemp].
abstract interface class BbtRepository {
  /// The reading logged for [date], or `null` if that day has none.
  Future<BbtEntry?> tempOn(DateTime date);

  /// Every logged reading, newest day first, as a stream that re-emits on change.
  Stream<List<BbtEntry>> watchAll();

  /// Record (or replace) the reading for [date]. [celsius] must be in the
  /// plausible range or a [BbtException] is thrown. Upserts on the day and
  /// preserves `created_at` when a row already exists.
  Future<void> setTemp(DateTime date, double celsius);

  /// Remove the reading logged for [date]. A no-op if that day has none.
  Future<void> clearTemp(DateTime date);
}
