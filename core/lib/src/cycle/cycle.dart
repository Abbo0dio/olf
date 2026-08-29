import 'package:meta/meta.dart';

import '../date_math.dart';
import 'pregnancy_event.dart';

/// A cycle length beyond which a period was more likely *not logged* than truly
/// this long. Normal cycles run ~21–35 days; irregular ones stretch further, but
/// past ~45 days a missed entry is the more plausible explanation, so a [Cycle]
/// this long is flagged [Cycle.isLikelyGap] and left out of the statistics.
const int longestPlausibleCycleDays = 45;

/// One menstrual cycle, **derived** from consecutive logged periods — never
/// stored. Day 1 is the first day of [periodStart]'s period; the cycle runs up
/// to the day before the next period begins.
///
/// The most recent cycle has no [nextPeriodStart] yet: it is still open, so its
/// [lengthInDays] is unknown ([isCurrent] is `true`).
@immutable
class Cycle {
  Cycle({
    required DateTime periodStart,
    DateTime? periodEnd,
    DateTime? nextPeriodStart,
    this.interruptedBy,
  }) : periodStart = dateOnly(periodStart),
       periodEnd = periodEnd == null ? null : dateOnly(periodEnd),
       nextPeriodStart = nextPeriodStart == null
           ? null
           : dateOnly(nextPeriodStart);

  /// First day of the period that opens this cycle.
  final DateTime periodStart;

  /// Last day of that period, or `null` if it is ongoing / no end was recorded.
  final DateTime? periodEnd;

  /// First day of the *next* logged period. `null` for the current cycle.
  final DateTime? nextPeriodStart;

  /// Set (p1.11) when a pregnancy-end event falls inside this cycle's span —
  /// the interval covers a pregnancy, not a normal cycle, so it is excluded
  /// from [CycleStats] the same way a [isLikelyGap] cycle is, and the
  /// predictor treats history on the far side of it as no longer current.
  final PregnancyEndKind? interruptedBy;

  /// `true` when this is the latest cycle and no following period is logged yet.
  bool get isCurrent => nextPeriodStart == null;

  /// Whole days from this period's start to the next period's start
  /// (start-to-start). `null` while the cycle is still current.
  int? get lengthInDays => nextPeriodStart == null
      ? null
      : daysBetween(periodStart, nextPeriodStart!);

  /// Whole days of bleeding, inclusive of both ends. `null` while no end date
  /// has been recorded for the period.
  int? get periodLengthInDays =>
      periodEnd == null ? null : daysBetween(periodStart, periodEnd!) + 1;

  /// `true` when this interval covers a recorded pregnancy loss or birth (p1.11).
  bool get isPregnancyGap => interruptedBy != null;

  /// `true` when [lengthInDays] is so long that a period was probably not
  /// logged in between (see [longestPlausibleCycleDays]). A pregnancy gap is
  /// reported through [isPregnancyGap], not here.
  bool get isLikelyGap {
    if (isPregnancyGap) return false;
    final length = lengthInDays;
    return length != null && length > longestPlausibleCycleDays;
  }

  @override
  bool operator ==(Object other) =>
      other is Cycle &&
      other.periodStart == periodStart &&
      other.periodEnd == periodEnd &&
      other.nextPeriodStart == nextPeriodStart &&
      other.interruptedBy == interruptedBy;

  @override
  int get hashCode =>
      Object.hash(periodStart, periodEnd, nextPeriodStart, interruptedBy);

  @override
  String toString() =>
      'Cycle(start: $periodStart, end: $periodEnd, next: $nextPeriodStart'
      '${interruptedBy == null ? '' : ', interruptedBy: ${interruptedBy!.name}'})';
}
