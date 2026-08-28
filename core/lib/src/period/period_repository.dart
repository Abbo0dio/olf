import '../db/app_database.dart';
import 'period_validation.dart';

/// Reads and writes logged periods.
///
/// This is the seam every period-aware Phase 1 feature builds on (flow logging,
/// cycle derivation, prediction). The overlap / impossible-range invariant is
/// enforced **here** — [addPeriod] and [updatePeriod] validate against the
/// current set and throw [PeriodValidationException] rather than write bad data,
/// so no screen can bypass the rule.
abstract interface class PeriodRepository {
  /// Every logged period, most recent start first.
  Future<List<Period>> allPeriods();

  /// Every logged period as a stream that re-emits on any insert / update /
  /// delete. Most recent start first.
  Stream<List<Period>> watchPeriods();

  /// Insert [draft]. Returns the new row id.
  ///
  /// Throws [PeriodValidationException] (nothing is written) if the draft
  /// overlaps an existing period or is an impossible range.
  Future<int> addPeriod(PeriodDraft draft);

  /// Replace the dates of the period with [id] from [draft].
  ///
  /// Only that row changes — no derived data is stored, so a correction never
  /// cascades onto other periods. Throws [PeriodValidationException] (nothing is
  /// written) if the edited range overlaps a *different* period or is
  /// impossible. A no-op if no such row exists.
  Future<void> updatePeriod(int id, PeriodDraft draft);

  /// Delete the period with [id]. A no-op if no such row exists.
  Future<void> deletePeriod(int id);
}
