import '../db/app_database.dart';
import '../db/tables.dart';

/// Reads and writes per-day cervical-mucus observations ([CervicalMucusEntry]).
///
/// One row per calendar day. There is nothing to validate — any
/// [CervicalMucusType] is acceptable — so this is a plain CRUD seam.
abstract interface class CervicalMucusRepository {
  /// The observation logged for [date], or `null` if that day has none.
  Future<CervicalMucusEntry?> mucusOn(DateTime date);

  /// Every logged observation, newest day first, as a stream.
  Stream<List<CervicalMucusEntry>> watchAll();

  /// Record (or replace) the observation for [date]. Upserts on the day and
  /// preserves `created_at`.
  Future<void> setMucus(DateTime date, CervicalMucusType type);

  /// Remove the observation logged for [date]. A no-op if that day has none.
  Future<void> clearMucus(DateTime date);
}
