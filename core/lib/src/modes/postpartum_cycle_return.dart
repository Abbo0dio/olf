import 'package:meta/meta.dart';

import '../cycle/cycle_derivation.dart';
import '../cycle/pregnancy_event.dart';
import '../date_math.dart';
import '../db/app_database.dart';

/// How settled the cycle looks after a recorded pregnancy loss or birth.
enum PostpartumSettling {
  /// No period has been logged since the event yet — olf is simply waiting.
  awaitingFirstPeriod,

  /// A first post-event period exists, but fewer than two completed post-event
  /// cycles — not enough to say anything about a pattern yet.
  firstCycleLogged,

  /// Two or more completed post-event cycles, and their lengths sit within a
  /// normal spread — cycles look like they are settling.
  settling,

  /// Two or more completed post-event cycles, but their lengths still vary
  /// widely — common for a while after a loss or birth.
  stillVariable,
}

/// A pure, derived read of where the cycle stands after a recorded pregnancy
/// loss or birth (p7.1). Built entirely from the existing period +
/// pregnancy-event history — there is no new table and no new predictor.
///
/// The variability read reuses p1.3's [CycleStats] classifier and is a
/// deliberately honest `null` ([regularity]) until at least two completed
/// post-event cycles exist. Nothing here fabricates a next-period estimate:
/// the p3 predictor stays anchored on logged periods and is simply "still
/// settling" until enough post-event cycles are logged.
@immutable
class PostpartumCycleReturn {
  const PostpartumCycleReturn({
    required this.eventKind,
    required this.eventDate,
    required this.daysSinceEvent,
    required this.firstPeriodDate,
    required this.postEventCycleStats,
    required this.settling,
  });

  /// Whether the recorded event was a loss or a birth — drives copy and which
  /// support resources are shown.
  final PregnancyEndKind eventKind;

  /// Calendar date of the recorded event.
  final DateTime eventDate;

  /// Whole days from [eventDate] to the injected "today", never negative (a
  /// future-dated event clamps to 0).
  final int daysSinceEvent;

  /// First period logged strictly after [eventDate], or `null` if none yet.
  final DateTime? firstPeriodDate;

  /// Cycle statistics over the post-event periods only (pre-event lengths never
  /// mix in). [CycleStats.empty] when no post-event period has been logged.
  final CycleStats postEventCycleStats;

  final PostpartumSettling settling;

  /// `true` once any period has been logged since the event.
  bool get firstPeriodLogged => firstPeriodDate != null;

  /// Completed, non-gap cycles logged since the event.
  int get postEventCycleCount => postEventCycleStats.completedCycleCount;

  /// The variability classification once there are at least two completed
  /// post-event cycles, otherwise `null` — no read is offered before then.
  CycleRegularity? get regularity =>
      postEventCycleCount >= 2 ? postEventCycleStats.regularity : null;

  @override
  bool operator ==(Object other) =>
      other is PostpartumCycleReturn &&
      other.eventKind == eventKind &&
      other.eventDate == eventDate &&
      other.daysSinceEvent == daysSinceEvent &&
      other.firstPeriodDate == firstPeriodDate &&
      other.postEventCycleStats == postEventCycleStats &&
      other.settling == settling;

  @override
  int get hashCode => Object.hash(
    eventKind,
    eventDate,
    daysSinceEvent,
    firstPeriodDate,
    postEventCycleStats,
    settling,
  );
}

/// Derive the postpartum cycle-return view from [events] and [periods] as of
/// [today] (injected — never `DateTime.now()`).
///
/// Returns `null` when there is no recorded pregnancy loss / birth at all —
/// there is nothing to show. Otherwise the most recent pregnancy-end anchors
/// the view; only periods that start strictly after it count as "the cycle
/// coming back".
PostpartumCycleReturn? derivePostpartumCycleReturn({
  required Iterable<PregnancyEvent> events,
  required Iterable<Period> periods,
  required DateTime today,
}) {
  final latest = mostRecentPregnancyEnd(events);
  if (latest == null) return null;

  final day = dateOnly(today);
  final rawDays = daysBetween(latest.date, day);
  final daysSinceEvent = rawDays < 0 ? 0 : rawDays;

  final postEventPeriods =
      periods.where((p) => dateOnly(p.startDate).isAfter(latest.date)).toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));

  final firstPeriodDate = postEventPeriods.isEmpty
      ? null
      : dateOnly(postEventPeriods.first.startDate);

  final stats = CycleStats.from(deriveCycles(postEventPeriods));

  final PostpartumSettling settling;
  if (firstPeriodDate == null) {
    settling = PostpartumSettling.awaitingFirstPeriod;
  } else if (stats.completedCycleCount < 2) {
    settling = PostpartumSettling.firstCycleLogged;
  } else {
    settling = switch (stats.regularity) {
      CycleRegularity.regular ||
      CycleRegularity.mostlyRegular => PostpartumSettling.settling,
      CycleRegularity.irregular => PostpartumSettling.stillVariable,
      // Not reachable with >= 2 completed cycles, but stay honest rather than
      // assert a read we can't back up.
      CycleRegularity.notEnoughData => PostpartumSettling.firstCycleLogged,
    };
  }

  return PostpartumCycleReturn(
    eventKind: latest.kind,
    eventDate: latest.date,
    daysSinceEvent: daysSinceEvent,
    firstPeriodDate: firstPeriodDate,
    postEventCycleStats: stats,
    settling: settling,
  );
}
