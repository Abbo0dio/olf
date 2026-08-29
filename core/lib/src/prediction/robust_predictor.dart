import 'dart:math' as math;

import '../cycle/cycle.dart';
import '../cycle/cycle_derivation.dart';
import '../date_math.dart';
import 'date_range.dart';
import 'predictor.dart';

/// Days from ovulation to the next period — the luteal phase. Far steadier
/// person-to-person than the follicular phase, so v1 treats it as fixed.
const int lutealPhaseDays = 14;

/// Sperm can stay viable up to this many days before ovulation …
const int fertileDaysBeforeOvulation = 5;

/// … and the egg for about this long after.
const int fertileDaysAfterOvulation = 1;

/// The predicted next-period window is never narrower than ±this, even for a
/// metronomic history — a date is never claimed to the day.
const int minPredictionMarginDays = 1;

/// Stats-based [Predictor]: anchor on the last logged period start, project the
/// median recent cycle length, and widen to the range those cycles actually
/// covered. Robust enough for v1; deliberately **not** adaptive — that is
/// Phase 3, which swaps this out behind the [Predictor] seam.
class RobustPredictor implements Predictor {
  const RobustPredictor();

  @override
  CyclePrediction? predict({
    required List<Cycle> cycles,
    required DateTime today,
  }) {
    if (cycles.isEmpty) return null;

    final stats = CycleStats.from(cycles);
    final typical = stats.typicalCycleLength;
    final shortest = stats.shortestCycleLength;
    final longest = stats.longestCycleLength;
    if (typical == null || shortest == null || longest == null) return null;

    // `cycles` is newest-first: the first is the current (open) cycle and its
    // start is the most recent logged period start — the only anchor we use, so
    // a late period never rolls the estimate forward on its own.
    final anchor = cycles.first.periodStart;
    final t = dateOnly(today);

    final back = math.max(minPredictionMarginDays, typical - shortest);
    final forward = math.max(minPredictionMarginDays, longest - typical);

    final expected = addDays(anchor, typical);
    final earliest = addDays(anchor, typical - back);
    final latest = addDays(anchor, typical + forward);

    final ovulation = addDays(expected, -lutealPhaseDays);
    final fertileWindow = DateRange(
      addDays(ovulation, -fertileDaysBeforeOvulation),
      addDays(ovulation, fertileDaysAfterOvulation),
    );

    final PredictionStatus status;
    final int? daysPastExpected;
    if (t.isBefore(earliest)) {
      status = PredictionStatus.upcoming;
      daysPastExpected = null;
    } else if (!t.isAfter(latest)) {
      status = PredictionStatus.dueNow;
      daysPastExpected = null;
    } else {
      status = PredictionStatus.overdue;
      daysPastExpected = daysBetween(expected, t);
    }

    return CyclePrediction(
      nextPeriod: DateRange(earliest, latest),
      nextPeriodExpected: expected,
      fertileWindow: fertileWindow,
      confidence: _confidence(stats),
      basedOnCycles: stats.completedCycleCount,
      status: status,
      daysPastExpected: daysPastExpected,
    );
  }

  PredictionConfidence _confidence(CycleStats stats) {
    if (stats.hasLikelyGap) return PredictionConfidence.low;
    final n = stats.completedCycleCount;
    final r = stats.regularity;
    if (r == CycleRegularity.regular && n >= 3) {
      return PredictionConfidence.high;
    }
    if ((r == CycleRegularity.regular || r == CycleRegularity.mostlyRegular) &&
        n >= 2) {
      return PredictionConfidence.medium;
    }
    return PredictionConfidence.low;
  }
}
