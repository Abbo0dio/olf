import '../db/app_database.dart';

/// Reads and writes cycle-timeline events.
///
/// This is the seam the whole of Phase 1 builds on. The only implementation
/// today is [DriftCycleEventRepository]; tests and future storage backends
/// implement the same interface.
abstract interface class CycleEventRepository {
  /// Record that the user's period started on [date] (the time-of-day is
  /// ignored — it is stored as a calendar date). Returns the new row id.
  Future<int> logPeriodStart(DateTime date);

  /// The most recent `periodStart` event, or `null` if none has been logged.
  Future<CycleEvent?> mostRecentPeriodStart();

  /// The most recent `periodStart` event as a stream that emits on every change
  /// (insert / delete). Emits `null` when there is none.
  Stream<CycleEvent?> watchMostRecentPeriodStart();

  /// Delete the event with [id]. A no-op if no such row exists.
  Future<void> deleteEvent(int id);
}
