import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../bbt/thermal_shift.dart';
import '../cycle/cycle.dart';
import '../cycle/cycle_derivation.dart';
import '../date_math.dart';
import '../db/app_database.dart';
import '../mucus/cervical_mucus.dart';
import '../mucus/fertile_window_signal.dart';
import '../prediction/date_range.dart';
import '../prediction/predictor.dart';
import '../prediction/robust_predictor.dart'
    show fertileDaysAfterOvulation, fertileDaysBeforeOvulation;

/// How much to trust a [DailyFertilityScore] — a deliberately coarse band, not
/// a percentage. It widens the plausible range around the point score and, when
/// low, pulls the score itself toward a humble baseline so a thin or irregular
/// history can never read as a confident number.
enum FertilityConfidence { none, low, medium, high }

/// A plain-language reason the score is where it is, surfaced to the user so the
/// number is never a black box. The score visibly *moves* with the first four.
enum FertilityFactor {
  /// Baseline: the p3 predictor's estimated fertile window for this cycle.
  predictedWindow,

  /// Raised: fertile-quality cervical mucus logged **today**.
  fertileMucusToday,

  /// Noted: fertile-quality cervical mucus logged earlier this cycle.
  fertileMucusRecent,

  /// Lowered: a confirmed BBT thermal shift means ovulation has most likely
  /// already passed and the fertile window has closed.
  thermalShiftPassed,

  /// Widened: too few completed cycles to be precise yet.
  thinHistory,

  /// Widened: recent cycle lengths vary a lot, so any single day is uncertain.
  irregularHistory,
}

/// A relative fertility estimate for one calendar day.
///
/// [score] is a bounded **relative likelihood drawn from the user's own
/// patterns** — never an absolute probability of conception and never 0 or 100
/// (no day is impossible or certain). It layers the logged BBT / mucus signals
/// on top of the existing p3 fertile-window estimate; it is not a second
/// prediction engine.
@immutable
class DailyFertilityScore {
  const DailyFertilityScore({
    required this.date,
    required this.score,
    required this.low,
    required this.high,
    required this.confidence,
    required this.fertileWindow,
    required this.peakDay,
    required this.factors,
  });

  /// The day this score is for.
  final DateTime date;

  /// Point estimate, `1`–`99`. Higher means more fertile relative to the rest
  /// of this person's cycle.
  final int score;

  /// The band around [score] implied by [confidence] (`0`–`100`, inclusive).
  final int low;
  final int high;

  final FertilityConfidence confidence;

  /// The fertile window to show the user — always a range, never a single day.
  /// Derived from the same estimated ovulation day the score uses, so the two
  /// never disagree.
  final DateRange fertileWindow;

  /// Estimated ovulation / peak-fertility day. [date] is the peak when it
  /// equals this.
  final DateTime peakDay;

  /// `true` when [date] is the estimated peak day.
  bool get isPeak => dateOnly(date) == dateOnly(peakDay);

  final List<FertilityFactor> factors;

  @override
  bool operator ==(Object other) =>
      other is DailyFertilityScore &&
      other.date == date &&
      other.score == score &&
      other.low == low &&
      other.high == high &&
      other.confidence == confidence &&
      other.fertileWindow == fertileWindow &&
      other.peakDay == peakDay &&
      _listEq(other.factors, factors);

  @override
  int get hashCode => Object.hash(
    date,
    score,
    low,
    high,
    confidence,
    fertileWindow,
    peakDay,
    Object.hashAll(factors),
  );
}

/// The score for [day], as of [today], or `null` when there is not enough
/// history to say anything honest — the caller shows a "keep logging" state.
///
/// Pure and clock-injected: [today] and [day] are passed in, there is no
/// `DateTime.now()`, and the same inputs always give the same result.
///
/// [prediction] is the p3 forecast for the current cycle (from `predictorProvider`
/// in the app); a `null` prediction, or fewer than two completed cycles, means
/// no score. [cycles] is newest-first as `deriveCycles` returns. [bbt] and
/// [mucus] are the full logged histories — only entries in the current cycle and
/// on or before [today] are used.
DailyFertilityScore? dailyFertilityScore({
  required List<Cycle> cycles,
  required Iterable<BbtEntry> bbt,
  required Iterable<CervicalMucusEntry> mucus,
  required CyclePrediction? prediction,
  required DateTime today,
  required DateTime day,
}) {
  if (prediction == null || cycles.isEmpty) return null;

  final stats = CycleStats.from(cycles);
  if (stats.completedCycleCount < 2) return null;

  final cycleStart = dateOnly(cycles.first.periodStart);
  final scoredDay = dateOnly(day);
  final asOf = dateOnly(today);

  // --- 1. estimated ovulation: the predictor's, unless a logged thermal shift
  //        has since confirmed one. The shift narrows and can move the window.
  final predictedOvulation = addDays(
    prediction.fertileWindow.end,
    -fertileDaysAfterOvulation,
  );
  final shift = thermalShift(bbt, cycleStart: cycleStart, today: asOf);
  final ovulation = shift?.estimatedOvulation ?? predictedOvulation;

  final factors = <FertilityFactor>[FertilityFactor.predictedWindow];

  // --- 2. base shape: a standard day-relative fertile curve about ovulation.
  final offset = daysBetween(ovulation, scoredDay);
  var shape = _relativeFertility(offset);

  // --- 3. observed fertile-quality mucus lifts a low predicted day: the body
  //        is signalling fertility now even if the estimate hasn't caught up.
  final observed = observedFertileWindow(
    mucus,
    cycleStart: cycleStart,
    today: asOf,
  );
  if (observed != null && observed.contains(scoredDay)) {
    shape = math.max(shape, _mucusShape);
    final fertileMucusToday =
        scoredDay == asOf &&
        mucus.any((e) => e.type.isFertileQuality && dateOnly(e.date) == asOf);
    factors.add(
      fertileMucusToday
          ? FertilityFactor.fertileMucusToday
          : FertilityFactor.fertileMucusRecent,
    );
  }

  // --- 4. a confirmed shift closes the window: days past ovulation + the
  //        egg's short viability are near-zero, with confidence.
  final windowClosed =
      shift != null &&
      offset > fertileDaysAfterOvulation &&
      scoredDay.isAfter(shift.shiftDate);
  if (windowClosed) {
    shape = math.min(shape, _closedWindowShape);
    factors.add(FertilityFactor.thermalShiftPassed);
  }

  // --- 5. confidence from history depth + regularity, tightened by an
  //        observed signal.
  final confidence = _confidence(
    prediction: prediction,
    stats: stats,
    hasShift: shift != null,
    hasMucusSignal: observed != null,
    factors: factors,
  );

  // --- 6. shrink toward a humble baseline when confidence is low — no fake
  //        precision from a thin or irregular history.
  final sharpness = switch (confidence) {
    FertilityConfidence.high => 1.0,
    FertilityConfidence.medium => 0.72,
    FertilityConfidence.low => 0.42,
    FertilityConfidence.none => 0.0,
  };
  final shrunk = _neutralBaseline + (shape - _neutralBaseline) * sharpness;
  final score = (shrunk * 100).round().clamp(1, 99);

  final halfWidth = switch (confidence) {
    FertilityConfidence.high => 6,
    FertilityConfidence.medium => 16,
    FertilityConfidence.low => 28,
    FertilityConfidence.none => 40,
  };

  return DailyFertilityScore(
    date: scoredDay,
    score: score,
    low: (score - halfWidth).clamp(0, 100),
    high: (score + halfWidth).clamp(0, 100),
    confidence: confidence,
    fertileWindow: DateRange(
      addDays(ovulation, -fertileDaysBeforeOvulation),
      addDays(ovulation, fertileDaysAfterOvulation),
    ),
    peakDay: ovulation,
    factors: List.unmodifiable(factors),
  );
}

/// [dailyFertilityScore] for [days] consecutive days starting at [today]
/// ("today and the next N−1 days"). Empty when there is not enough history.
List<DailyFertilityScore> dailyFertilityScores({
  required List<Cycle> cycles,
  required Iterable<BbtEntry> bbt,
  required Iterable<CervicalMucusEntry> mucus,
  required CyclePrediction? prediction,
  required DateTime today,
  int days = 8,
}) {
  if (prediction == null) return const [];
  final bbtList = bbt.toList();
  final mucusList = mucus.toList();
  final out = <DailyFertilityScore>[];
  for (var i = 0; i < days; i++) {
    final s = dailyFertilityScore(
      cycles: cycles,
      bbt: bbtList,
      mucus: mucusList,
      prediction: prediction,
      today: today,
      day: addDays(today, i),
    );
    if (s == null) return const [];
    out.add(s);
  }
  return out;
}

/// A low "some chance on any cycle day" floor on the 0–1 shape scale. A
/// low-confidence score is pulled toward this so it never reads as precise.
const double _neutralBaseline = 0.12;

/// Shape value for a day inside the observed fertile-mucus bracket.
const double _mucusShape = 0.8;

/// Shape ceiling once a thermal shift has confirmed the window is closed.
const double _closedWindowShape = 0.02;

/// Relative fertility on a 0–1 scale for a day [offset] days from estimated
/// ovulation (negative = before). A standard fertile-window shape: a run-up over
/// the ~5 days before ovulation, a peak on ovulation day and the day before, a
/// sharp fall after. Never zero — no day is declared impossible.
double _relativeFertility(int offset) => switch (offset) {
  -5 => 0.05,
  -4 => 0.10,
  -3 => 0.22,
  -2 => 0.55,
  -1 => 0.90,
  0 => 1.0,
  1 => 0.28,
  2 => 0.05,
  _ => 0.01,
};

FertilityConfidence _confidence({
  required CyclePrediction prediction,
  required CycleStats stats,
  required bool hasShift,
  required bool hasMucusSignal,
  required List<FertilityFactor> factors,
}) {
  // Start from the predictor's own read — it already folds in depth, spread and
  // regime change.
  var level = switch (prediction.confidence) {
    PredictionConfidence.high => 3,
    PredictionConfidence.medium => 2,
    PredictionConfidence.low => 1,
  };

  final thin = stats.completedCycleCount < 3;
  final irregular =
      stats.hasLikelyGap || stats.regularity == CycleRegularity.irregular;
  if (thin) level = math.min(level, 2);
  if (irregular) level = math.min(level, 1);

  // An observed signal is worth more than any estimate.
  if (hasShift) level += 1;
  if (hasMucusSignal) level += 1;
  level = level.clamp(1, 3);

  // Only flag a widening reason when the band actually stayed wide.
  if (level < 3) {
    if (irregular) factors.add(FertilityFactor.irregularHistory);
    if (thin && !irregular) factors.add(FertilityFactor.thinHistory);
  }

  return switch (level) {
    >= 3 => FertilityConfidence.high,
    2 => FertilityConfidence.medium,
    _ => FertilityConfidence.low,
  };
}

bool _listEq(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
