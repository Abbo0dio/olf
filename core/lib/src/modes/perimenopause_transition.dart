import 'package:meta/meta.dart';

import '../cycle/cycle.dart';
import '../cycle/cycle_derivation.dart';
import '../date_math.dart';
import '../db/app_database.dart';

/// How recent cycle history is trending — coarse and honest, never a number.
enum PerimenopauseVariabilityTrend {
  /// Not enough completed cycles on both sides of the window to compare.
  notEnoughData,

  /// Cycle-length spread and skip frequency look about the same as before.
  noClearChange,

  /// Spread is widening and/or skipped cycles are more frequent lately.
  becomingLessRegular,
}

/// A deliberately coarse, hedged descriptive read of where things might be in
/// the perimenopause transition. **Not** a stage number, a percentage, or a
/// "score" (§9(12)) — a short honest label at most, and the copy that renders
/// it says plainly that it is not a medical assessment.
enum PerimenopauseStageHint {
  /// Too little logged history to say anything.
  notEnoughData,

  /// Recent cycles look about as regular as before — no clear change.
  cyclesLookRegular,

  /// Recent cycles are becoming less regular (widening spread / more skips).
  cyclesBecomingLessRegular,

  /// One or more long gaps between recent cycles.
  longGapsAppearing,

  /// 12+ months since the last logged period (the common definition of
  /// menopause) — surfaced factually, not as a diagnosis.
  twelveMonthsPlus,
}

/// A pure, derived read over the logged period history for perimenopause mode
/// (p7.7). Built entirely from [deriveCycles] + [CycleStats] + the existing gap
/// logic — no new table, no new predictor, and nothing here fabricates a
/// forecast.
///
/// Everything is descriptive: increasing variability and skipped cycles are the
/// *expected* signal in this stage, so they are reported as facts about the
/// user's own log, never as an alarm and never as a numeric score.
@immutable
class PerimenopauseTransitionRead {
  const PerimenopauseTransitionRead({
    required this.monthsOfHistory,
    required this.completedCycleCount,
    required this.variabilityTrend,
    required this.earlierSpreadDays,
    required this.laterSpreadDays,
    required this.recentSkipCount,
    required this.longGapsBetweenCycles,
    required this.daysSinceLastPeriod,
    required this.stageHint,
  });

  /// Whole months from the first logged period to the injected "today".
  final int monthsOfHistory;

  /// Completed, non-gap cycles available (capped at [_window]).
  final int completedCycleCount;

  final PerimenopauseVariabilityTrend variabilityTrend;

  /// Cycle-length spread (longest − shortest) in the earlier / later half of
  /// the recent window, or `null` when that half has fewer than two non-gap
  /// completed cycles.
  final int? earlierSpreadDays;
  final int? laterSpreadDays;

  /// Likely-missed-entry ("skipped") cycles among the recent completed cycles.
  final int recentSkipCount;

  /// `true` when recent history shows one or more long gaps between cycles, or
  /// the current open stretch is already longer than a plausible cycle.
  final bool longGapsBetweenCycles;

  /// Whole days from the most recent logged period start to "today", clamped to
  /// `0` for a future-dated period.
  final int daysSinceLastPeriod;

  final PerimenopauseStageHint stageHint;

  /// `true` once at least 12 months have passed since the last logged period —
  /// the common definition of menopause. Information, not a diagnosis.
  bool get twelveMonthsSinceLastPeriod => daysSinceLastPeriod >= 365;

  /// Whether the variability trend is backed by enough history to state.
  bool get trendIsMeaningful =>
      variabilityTrend != PerimenopauseVariabilityTrend.notEnoughData;

  @override
  bool operator ==(Object other) =>
      other is PerimenopauseTransitionRead &&
      other.monthsOfHistory == monthsOfHistory &&
      other.completedCycleCount == completedCycleCount &&
      other.variabilityTrend == variabilityTrend &&
      other.earlierSpreadDays == earlierSpreadDays &&
      other.laterSpreadDays == laterSpreadDays &&
      other.recentSkipCount == recentSkipCount &&
      other.longGapsBetweenCycles == longGapsBetweenCycles &&
      other.daysSinceLastPeriod == daysSinceLastPeriod &&
      other.stageHint == stageHint;

  @override
  int get hashCode => Object.hash(
    monthsOfHistory,
    completedCycleCount,
    variabilityTrend,
    earlierSpreadDays,
    laterSpreadDays,
    recentSkipCount,
    longGapsBetweenCycles,
    daysSinceLastPeriod,
    stageHint,
  );
}

/// Only the most recent this-many completed cycles feed the trend comparison —
/// mirrors [CycleStats.recentWindow].
const int _window = 12;

/// Each half of the window needs at least this many non-gap completed cycles
/// before a spread is computed for it.
const int _minPerHalf = 2;

/// The later half's spread must exceed the earlier half's by at least this many
/// days to call the trend "becoming less regular" on spread alone.
const int perimenopauseSpreadWideningDays = 5;

/// Derive the perimenopause transition read from [periods] as of [today]
/// (injected — never `DateTime.now()`).
///
/// Returns `null` when no period is logged at all — there is nothing to show.
PerimenopauseTransitionRead? derivePerimenopauseTransition({
  required Iterable<Period> periods,
  required DateTime today,
}) {
  final sorted = periods.toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
  if (sorted.isEmpty) return null;

  final day = dateOnly(today);
  final lastStart = dateOnly(sorted.last.startDate);
  final rawSince = daysBetween(lastStart, day);
  final daysSinceLastPeriod = rawSince < 0 ? 0 : rawSince;

  final firstStart = dateOnly(sorted.first.startDate);
  final rawMonths = daysBetween(firstStart, day) ~/ 30;
  final monthsOfHistory = rawMonths < 0 ? 0 : rawMonths;

  // Newest-first, like the rest of core. Drop any pre-pregnancy history the
  // same way CycleStats does — a recorded loss / birth resets the baseline.
  final cycles = deriveCycles(
    sorted,
  ).takeWhile((c) => !c.isPregnancyGap).toList();
  final completed = cycles.where((c) => !c.isCurrent).toList();
  final recent = completed.take(_window).toList();

  final recentSkipCount = recent.where((c) => c.isLikelyGap).length;
  final currentlyInLongGap = daysSinceLastPeriod > longestPlausibleCycleDays;
  final longGapsBetweenCycles = recentSkipCount > 0 || currentlyInLongGap;

  // Split the recent window oldest→newest into two halves and compare the
  // cycle-length spread (and skip count) across them.
  final chrono = recent.reversed.toList();
  final mid = chrono.length ~/ 2;
  final earlier = chrono.sublist(0, mid);
  final later = chrono.sublist(mid);

  final earlierSpread = _spread(earlier);
  final laterSpread = _spread(later);
  final earlierSkips = earlier.where((c) => c.isLikelyGap).length;
  final laterSkips = later.where((c) => c.isLikelyGap).length;

  final PerimenopauseVariabilityTrend trend;
  if (earlierSpread == null || laterSpread == null) {
    trend = PerimenopauseVariabilityTrend.notEnoughData;
  } else if (laterSpread - earlierSpread >= perimenopauseSpreadWideningDays ||
      laterSkips > earlierSkips) {
    trend = PerimenopauseVariabilityTrend.becomingLessRegular;
  } else {
    trend = PerimenopauseVariabilityTrend.noClearChange;
  }

  final PerimenopauseStageHint hint;
  if (daysSinceLastPeriod >= 365) {
    hint = PerimenopauseStageHint.twelveMonthsPlus;
  } else if (longGapsBetweenCycles) {
    hint = PerimenopauseStageHint.longGapsAppearing;
  } else if (trend == PerimenopauseVariabilityTrend.becomingLessRegular) {
    hint = PerimenopauseStageHint.cyclesBecomingLessRegular;
  } else if (trend == PerimenopauseVariabilityTrend.noClearChange) {
    hint = PerimenopauseStageHint.cyclesLookRegular;
  } else {
    hint = PerimenopauseStageHint.notEnoughData;
  }

  return PerimenopauseTransitionRead(
    monthsOfHistory: monthsOfHistory,
    completedCycleCount: recent.where((c) => !c.isLikelyGap).length,
    variabilityTrend: trend,
    earlierSpreadDays: earlierSpread,
    laterSpreadDays: laterSpread,
    recentSkipCount: recentSkipCount,
    longGapsBetweenCycles: longGapsBetweenCycles,
    daysSinceLastPeriod: daysSinceLastPeriod,
    stageHint: hint,
  );
}

/// Cycle-length spread (longest − shortest) over the non-gap completed cycles
/// in [half], or `null` when there are fewer than [_minPerHalf] of them. Reuses
/// [CycleStats] so the "which cycles count" rules stay in one place.
int? _spread(List<Cycle> half) {
  final stats = CycleStats.from(half);
  if (stats.completedCycleCount < _minPerHalf) return null;
  final shortest = stats.shortestCycleLength;
  final longest = stats.longestCycleLength;
  if (shortest == null || longest == null) return null;
  return longest - shortest;
}
