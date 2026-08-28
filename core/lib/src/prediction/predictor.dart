import 'package:meta/meta.dart';

import '../cycle/cycle.dart';
import 'date_range.dart';

/// How much to trust a [CyclePrediction], derived from how regular and how deep
/// the logged history is. Deliberately coarse — this is a hint, not a promise.
enum PredictionConfidence { low, medium, high }

/// Where "now" sits relative to the predicted next period.
enum PredictionStatus {
  /// Today is before the predicted window.
  upcoming,

  /// Today is inside the predicted window.
  dueNow,

  /// Today is past the predicted window and no new period has been logged. The
  /// prediction is **not** rolled forward — the app shows a check-in instead.
  overdue,
}

/// A humble, correctable forecast built from the user's own history.
///
/// Dates are always exposed as ranges ([nextPeriod], [fertileWindow]); the
/// single [nextPeriodExpected] day is the midpoint estimate for copy like
/// "most likely the 14th", never shown on its own without the range.
@immutable
class CyclePrediction {
  const CyclePrediction({
    required this.nextPeriod,
    required this.nextPeriodExpected,
    required this.fertileWindow,
    required this.confidence,
    required this.basedOnCycles,
    required this.status,
    required this.daysPastExpected,
  });

  /// Window the next period is expected to start in.
  final DateRange nextPeriod;

  /// Midpoint estimate within [nextPeriod]. Anchored to the last logged period
  /// start plus the typical cycle length — it does **not** advance on its own
  /// once a period is late.
  final DateTime nextPeriodExpected;

  /// Estimated fertile window for the coming cycle (a ~7-day span ending a
  /// couple of days after estimated ovulation).
  final DateRange fertileWindow;

  final PredictionConfidence confidence;

  /// How many completed cycles the estimate is based on.
  final int basedOnCycles;

  final PredictionStatus status;

  /// Whole days between [nextPeriodExpected] and today, when [status] is
  /// [PredictionStatus.overdue]; otherwise `null`.
  final int? daysPastExpected;

  bool get isOverdue => status == PredictionStatus.overdue;

  @override
  bool operator ==(Object other) =>
      other is CyclePrediction &&
      other.nextPeriod == nextPeriod &&
      other.nextPeriodExpected == nextPeriodExpected &&
      other.fertileWindow == fertileWindow &&
      other.confidence == confidence &&
      other.basedOnCycles == basedOnCycles &&
      other.status == status &&
      other.daysPastExpected == daysPastExpected;

  @override
  int get hashCode => Object.hash(
    nextPeriod,
    nextPeriodExpected,
    fertileWindow,
    confidence,
    basedOnCycles,
    status,
    daysPastExpected,
  );
}

/// Turns a cycle history into a [CyclePrediction].
///
/// This is a seam, not the final engine: p1.4 ships a correct, humble
/// stats-based implementation ([RobustPredictor]); Phase 3 replaces it with an
/// adaptive, backtested model **without touching call sites**.
abstract interface class Predictor {
  /// Predict from [cycles] (newest first, as `deriveCycles` returns them).
  /// [today] is injected so the result is deterministic and offline.
  ///
  /// Returns `null` when the history is too thin to say anything useful — the
  /// caller shows a "keep logging" state, never a fabricated date.
  CyclePrediction? predict({
    required List<Cycle> cycles,
    required DateTime today,
  });
}
