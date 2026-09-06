import 'package:meta/meta.dart';

import '../cycle/cycle.dart';
import '../cycle/cycle_phase.dart';
import '../date_math.dart';

/// A single dated, categorical event — the generic unit [cyclePhaseCorrelations]
/// tallies. [category] is opaque: a symptom name, a flare marker, a rating
/// bucket. The correlation never parses or ranks it, it only counts how its
/// days fall across cycle phase.
///
/// PCOS mode (p7.4) is the first caller, passing one event per logged symptom
/// day. p7.5–p7.7 reuse the same core with their own event streams.
@immutable
class PhaseEvent {
  const PhaseEvent({required this.day, required this.category});

  /// The calendar day the event was logged on (time is ignored).
  final DateTime day;

  /// Opaque grouping key — one [PhaseCorrelation] is produced per distinct
  /// value.
  final String category;
}

/// A descriptive, non-clinical read of how one [category]'s logged days fall
/// across the four cycle phases over a range of history.
///
/// This is a "what your own log shows" summary — counts and a plain
/// "shows up most in X" / "no clear pattern" / "not enough data yet". It is
/// deliberately **not** a statistical test: there is no p-value, no confidence
/// interval, no causal claim, and nothing here is a diagnosis.
@immutable
class PhaseCorrelation {
  const PhaseCorrelation({
    required this.category,
    required this.totalDays,
    required this.daysByPhase,
    required this.enoughData,
    required this.showsUpMostIn,
  });

  final String category;

  /// Every logged day for this category inside the analysed range, including
  /// days that did not fall inside any derived phase segment.
  final int totalDays;

  /// Days that landed inside a phase segment, split by phase, iterating in
  /// [CyclePhaseKind] order. Days in a likely-missed-entry gap, a pregnancy
  /// gap, or the open current cycle are not counted here (see [placedDays]).
  final Map<CyclePhaseKind, int> daysByPhase;

  /// Whether there is enough logged history to say anything at all. `false`
  /// means show "not enough data yet" and ignore [showsUpMostIn].
  final bool enoughData;

  /// The one phase this category shows up in noticeably more than the others,
  /// measured per day of that phase so an unequal phase length does not bias
  /// the read. `null` for an even spread ("no clear pattern"), and always
  /// `null` when [enoughData] is `false`.
  final CyclePhaseKind? showsUpMostIn;

  /// Days that fell inside a phase segment.
  int get placedDays => daysByPhase.values.fold(0, (sum, n) => sum + n);
}

/// At least this many completed, non-gap cycles must be in range before any
/// per-category read is offered.
const int correlationMinCompletedCycles = 2;

/// …and at least this many of a category's logged days must land inside a phase
/// segment.
const int correlationMinPlacedDays = 5;

/// A phase is called out only when the category's rate there — logged days per
/// day of that phase — is at least this multiple of the mean per-phase rate.
const double correlationConcentrationRatio = 1.5;

/// Derive a descriptive per-category cycle-phase summary from [events] and the
/// derived [cycles], as of [today] (injected — never `DateTime.now()`).
///
/// Deterministic: identical inputs give an identical result, ordered by
/// [PhaseCorrelation.category]. Events dated after [today] are ignored, matching
/// the rest of `core`. The caller owns the range — pass the cycles and events
/// for the window it wants summarised.
List<PhaseCorrelation> cyclePhaseCorrelations({
  required Iterable<PhaseEvent> events,
  required Iterable<Cycle> cycles,
  required DateTime today,
}) {
  final day = dateOnly(today);
  final timeline = cyclePhaseTimeline(cycles, today: day);

  // Per-phase total span across the analysed range — the denominator for the
  // rate comparison in [_concentratedPhase].
  final phaseSpanDays = <CyclePhaseKind, int>{
    for (final kind in CyclePhaseKind.values) kind: 0,
  };
  for (final seg in timeline) {
    phaseSpanDays[seg.kind] = phaseSpanDays[seg.kind]! + seg.lengthInDays;
  }

  final completedCycles = cycles
      .where((c) => !c.isCurrent && !c.isLikelyGap && !c.isPregnancyGap)
      .length;

  final byCategory = <String, List<DateTime>>{};
  for (final e in events) {
    final d = dateOnly(e.day);
    if (d.isAfter(day)) continue;
    (byCategory[e.category] ??= <DateTime>[]).add(d);
  }

  CyclePhaseKind? phaseOn(DateTime d) {
    for (final seg in timeline) {
      if (seg.contains(d)) return seg.kind;
    }
    return null;
  }

  final results = <PhaseCorrelation>[];
  for (final entry in byCategory.entries) {
    final counts = <CyclePhaseKind, int>{
      for (final kind in CyclePhaseKind.values) kind: 0,
    };
    for (final d in entry.value) {
      final kind = phaseOn(d);
      if (kind != null) counts[kind] = counts[kind]! + 1;
    }
    final placed = counts.values.fold(0, (s, n) => s + n);
    final enough =
        completedCycles >= correlationMinCompletedCycles &&
        placed >= correlationMinPlacedDays;

    results.add(
      PhaseCorrelation(
        category: entry.key,
        totalDays: entry.value.length,
        daysByPhase: Map.unmodifiable(counts),
        enoughData: enough,
        showsUpMostIn: enough
            ? _concentratedPhase(counts, phaseSpanDays)
            : null,
      ),
    );
  }

  results.sort((a, b) => a.category.compareTo(b.category));
  return results;
}

/// The phase whose per-phase-day rate stands out from the mean, or `null` for
/// an even spread. Only phases that actually occur in the range are considered.
CyclePhaseKind? _concentratedPhase(
  Map<CyclePhaseKind, int> counts,
  Map<CyclePhaseKind, int> phaseSpanDays,
) {
  final rates = <CyclePhaseKind, double>{};
  for (final kind in CyclePhaseKind.values) {
    final span = phaseSpanDays[kind]!;
    if (span > 0) rates[kind] = counts[kind]! / span;
  }
  if (rates.length < 2) return null; // nothing to stand out from

  final meanRate = rates.values.fold(0.0, (s, r) => s + r) / rates.length;
  if (meanRate == 0) return null;

  CyclePhaseKind? top;
  var topRate = 0.0;
  for (final kind in CyclePhaseKind.values) {
    final r = rates[kind];
    if (r != null && r > topRate) {
      topRate = r;
      top = kind;
    }
  }
  if (top == null || counts[top]! < 2) return null;
  return topRate >= correlationConcentrationRatio * meanRate ? top : null;
}
