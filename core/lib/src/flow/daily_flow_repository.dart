import '../db/app_database.dart';
import '../db/tables.dart';

/// Reads and writes per-day flow logs ([DailyFlow]).
///
/// One row per calendar day. There is nothing to validate — any [FlowIntensity]
/// is acceptable and clots are optional — so this is a plain CRUD seam. The UI
/// decides *when* to offer logging (period days + today).
abstract interface class DailyFlowRepository {
  /// The flow logged for [date], or `null` if that day has none.
  Future<DailyFlow?> flowOn(DateTime date);

  /// Every logged day as a stream that re-emits on any change.
  Stream<List<DailyFlow>> watchAll();

  /// Record (or replace) the flow for [date]. Upserts on the day; `created_at`
  /// is preserved when a row already exists.
  Future<void> setFlow(
    DateTime date, {
    required FlowIntensity intensity,
    ClotSize? clotSize,
  });

  /// Remove the flow logged for [date]. A no-op if that day has none.
  Future<void> clearFlow(DateTime date);
}
