import 'package:meta/meta.dart';

import '../date_math.dart';
import '../db/app_database.dart';
import 'cycle.dart';
import 'pregnancy_event.dart';

/// Derive the cycle history from logged [periods].
///
/// Periods are paired start-to-start: each one opens a cycle that closes when
/// the next period begins. The most recent period opens the current, still-open
/// cycle ([Cycle.isCurrent]). Input order does not matter; the result is
/// **newest cycle first**, matching `periodsProvider`.
///
/// [pregnancyEvents] (p1.11): if a loss / birth falls inside a cycle's span
/// (strictly after its `periodStart`, and before the next period start if there
/// is one), that cycle is marked [Cycle.isPregnancyGap] — the interval covers a
/// pregnancy, not a normal cycle. When several events fall in one span the most
/// recent one wins.
///
/// Edge cases are deliberate, not accidental:
/// * no periods → empty list;
/// * one period → a single current cycle with no length;
/// * a very long interval → a [Cycle] with [Cycle.isLikelyGap] set, kept in the
///   history but excluded from [CycleStats].
List<Cycle> deriveCycles(
  Iterable<Period> periods, {
  Iterable<PregnancyEvent> pregnancyEvents = const [],
}) {
  final sorted = periods.toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));

  final events = pregnancyEvents.toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  PregnancyEndKind? interruptionFor(DateTime start, DateTime? nextStart) {
    final from = dateOnly(start);
    PregnancyEndKind? kind;
    for (final e in events) {
      if (e.date.isAfter(from) &&
          (nextStart == null || e.date.isBefore(dateOnly(nextStart)))) {
        kind = e.kind; // events are date-sorted, so the last match is newest
      }
    }
    return kind;
  }

  final cycles = <Cycle>[
    for (var i = 0; i < sorted.length; i++)
      Cycle(
        periodStart: sorted[i].startDate,
        periodEnd: sorted[i].endDate,
        nextPeriodStart: i + 1 < sorted.length ? sorted[i + 1].startDate : null,
        interruptedBy: interruptionFor(
          sorted[i].startDate,
          i + 1 < sorted.length ? sorted[i + 1].startDate : null,
        ),
      ),
  ];

  return cycles.reversed.toList();
}

/// How much recent cycle lengths vary. A deliberately coarse, honest signal —
/// not a medical assessment.
enum CycleRegularity {
  /// Fewer than two completed, non-gap cycles — nothing to compare yet.
  notEnoughData,

  /// Recent cycle lengths span at most [CycleStats.regularSpreadDays] days.
  regular,

  /// They span at most [CycleStats.mostlyRegularSpreadDays] days.
  mostlyRegular,

  /// They span more than that.
  irregular,
}

/// Summary statistics over a derived cycle history.
///
/// All length figures are computed from **completed** cycles only (the current
/// cycle has no length yet) and **exclude** likely-gap cycles, so one missed
/// entry does not distort the numbers. Every figure is nullable and is `null`
/// when there is not enough history — there is no 28-day fallback anywhere.
@immutable
class CycleStats {
  const CycleStats({
    required this.completedCycleCount,
    required this.typicalCycleLength,
    required this.shortestCycleLength,
    required this.longestCycleLength,
    required this.typicalPeriodLength,
    required this.regularity,
    required this.hasLikelyGap,
  });

  /// Completed, non-gap cycles the figures below are based on (capped at
  /// [recentWindow]).
  final int completedCycleCount;

  /// Median length of recent completed cycles, or `null` with none.
  final int? typicalCycleLength;

  /// Shortest / longest recent completed cycle, or `null` with none.
  final int? shortestCycleLength;
  final int? longestCycleLength;

  /// Median recorded period length across the history, or `null` if no period
  /// has an end date yet.
  final int? typicalPeriodLength;

  final CycleRegularity regularity;

  /// `true` when any derived cycle looked like a missed entry (see
  /// [Cycle.isLikelyGap]) — surface it rather than hide the assumption.
  final bool hasLikelyGap;

  /// Cycle-length spreads (max − min) up to and including this are [regular].
  static const int regularSpreadDays = 4;

  /// …and up to this are [mostlyRegular].
  static const int mostlyRegularSpreadDays = 9;

  /// Only the most recent this-many completed non-gap cycles feed the figures.
  static const int recentWindow = 12;

  static const CycleStats empty = CycleStats(
    completedCycleCount: 0,
    typicalCycleLength: null,
    shortestCycleLength: null,
    longestCycleLength: null,
    typicalPeriodLength: null,
    regularity: CycleRegularity.notEnoughData,
    hasLikelyGap: false,
  );

  factory CycleStats.from(Iterable<Cycle> cycles) {
    final all = cycles.toList();
    if (all.isEmpty) return empty;

    // `cycles` is newest-first. A recorded pregnancy loss / birth resets the
    // baseline (p1.11): only cycles more recent than the latest such gap feed
    // the figures, so pre-pregnancy lengths never mix into the current picture.
    final recent = all.takeWhile((c) => !c.isPregnancyGap).toList();

    // The most recent completed, non-(likely-)gap cycles.
    final recentLengths = <int>[
      for (final c in recent)
        if (!c.isCurrent && !c.isLikelyGap) c.lengthInDays!,
    ].take(recentWindow).toList();

    final periodLengths = <int>[
      for (final c in recent)
        if (c.periodLengthInDays != null) c.periodLengthInDays!,
    ];

    final anyGap = recent.any((c) => c.isLikelyGap);

    if (recentLengths.isEmpty) {
      return CycleStats(
        completedCycleCount: 0,
        typicalCycleLength: null,
        shortestCycleLength: null,
        longestCycleLength: null,
        typicalPeriodLength: _median(periodLengths),
        regularity: CycleRegularity.notEnoughData,
        hasLikelyGap: anyGap,
      );
    }

    final shortest = recentLengths.reduce((a, b) => a < b ? a : b);
    final longest = recentLengths.reduce((a, b) => a > b ? a : b);
    final spread = longest - shortest;

    final regularity = recentLengths.length < 2
        ? CycleRegularity.notEnoughData
        : spread <= regularSpreadDays
        ? CycleRegularity.regular
        : spread <= mostlyRegularSpreadDays
        ? CycleRegularity.mostlyRegular
        : CycleRegularity.irregular;

    return CycleStats(
      completedCycleCount: recentLengths.length,
      typicalCycleLength: _median(recentLengths),
      shortestCycleLength: shortest,
      longestCycleLength: longest,
      typicalPeriodLength: _median(periodLengths),
      regularity: regularity,
      hasLikelyGap: anyGap,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CycleStats &&
      other.completedCycleCount == completedCycleCount &&
      other.typicalCycleLength == typicalCycleLength &&
      other.shortestCycleLength == shortestCycleLength &&
      other.longestCycleLength == longestCycleLength &&
      other.typicalPeriodLength == typicalPeriodLength &&
      other.regularity == regularity &&
      other.hasLikelyGap == hasLikelyGap;

  @override
  int get hashCode => Object.hash(
    completedCycleCount,
    typicalCycleLength,
    shortestCycleLength,
    longestCycleLength,
    typicalPeriodLength,
    regularity,
    hasLikelyGap,
  );
}

/// Median of [values], rounded to the nearest whole day (half rounds up).
/// `null` for an empty input.
int? _median(List<int> values) {
  if (values.isEmpty) return null;
  final sorted = values.toList()..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid];
  return ((sorted[mid - 1] + sorted[mid]) / 2).round();
}
