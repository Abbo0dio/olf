import 'package:meta/meta.dart';

import '../date_math.dart';
import '../prediction/predictor.dart';
import 'cycle.dart';

/// The four physiologically distinct segments of a menstrual cycle (p1.12).
///
/// Never the *only* way a phase is communicated (WCAG 1.4.1) — always paired
/// with [label] as visible/spoken text, never color alone.
enum CyclePhaseKind { menstrual, follicular, ovulatory, luteal }

extension CyclePhaseKindLabel on CyclePhaseKind {
  /// Plain-language label for the ring segment and the center readout.
  String get label => switch (this) {
    CyclePhaseKind.menstrual => 'Menstrual',
    CyclePhaseKind.follicular => 'Follicular',
    CyclePhaseKind.ovulatory => 'Ovulatory',
    CyclePhaseKind.luteal => 'Luteal',
  };
}

/// One arc of the wheel — a [kind] and the inclusive day span it covers.
///
/// [end] may fall before [start] when a very short or degenerate estimate
/// collapses this phase to nothing (e.g. an unusually short follicular gap);
/// [lengthInDays] reports `0` rather than a negative count, and no day ever
/// [contains]s such a segment. The wheel widget is free to give a
/// zero-or-near-zero segment a small minimum arc width for legibility — that
/// is a drawing choice, not a claim about the underlying estimate.
@immutable
class CyclePhaseSegment {
  const CyclePhaseSegment({
    required this.kind,
    required this.start,
    required this.end,
  });

  final CyclePhaseKind kind;
  final DateTime start;
  final DateTime end;

  /// Whole days covered, inclusive of both ends; `0` if [end] is before
  /// [start].
  int get lengthInDays {
    final raw = daysBetween(start, end) + 1;
    return raw < 0 ? 0 : raw;
  }

  /// `true` when [day]'s calendar date falls within this segment.
  bool contains(DateTime day) {
    final d = dateOnly(day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  @override
  bool operator ==(Object other) =>
      other is CyclePhaseSegment &&
      other.kind == kind &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(kind, start, end);
}

/// Where [today] sits in the current cycle: the four [segments], in order
/// (menstrual, follicular, ovulatory, luteal), and which one [today] falls
/// in.
@immutable
class CyclePhase {
  const CyclePhase({
    required this.today,
    required this.segments,
    required this.currentIndex,
  }) : assert(
         segments.length == 4,
         'CyclePhase always carries all four phases, even a zero-length one',
       );

  /// The day this phase was derived for (calendar date, time stripped).
  final DateTime today;

  /// Always the four phases in cycle order — menstrual, follicular,
  /// ovulatory, luteal — even when one of them is zero-length.
  final List<CyclePhaseSegment> segments;

  /// Index into [segments] that [today] falls in. When [today] is past every
  /// segment (the period is overdue and hasn't been logged yet), this is the
  /// last segment (luteal) — the honest "still waiting" phase, not a
  /// fabricated fifth one.
  final int currentIndex;

  CyclePhaseSegment get current => segments[currentIndex];

  /// 1-based day count within [current], for a "Day 3" style readout. Can
  /// exceed [CyclePhaseSegment.lengthInDays] when the period is overdue —
  /// that is the honest signal that the estimate has been passed, not a bug.
  int get dayInPhase => daysBetween(current.start, today) + 1;

  @override
  bool operator ==(Object other) {
    if (other is! CyclePhase ||
        other.today != today ||
        other.currentIndex != currentIndex ||
        other.segments.length != segments.length) {
      return false;
    }
    for (var i = 0; i < segments.length; i++) {
      if (other.segments[i] != segments[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(today, currentIndex, Object.hashAll(segments));
}

/// Derives where [today] sits in the cycle from the current [cycle] and the
/// current [prediction] — a pure **derivation**, not a new predictor. Phase
/// boundaries are personalized to this user's own predicted lengths, never
/// fixed textbook proportions:
///   - menstrual: the logged period ([cycle.periodStart]..[cycle.periodEnd],
///     or through [today] while the period is still open);
///   - follicular: period end → [CyclePrediction.fertileWindow] start;
///   - ovulatory: [CyclePrediction.fertileWindow];
///   - luteal: fertile-window end → [CyclePrediction.nextPeriodExpected].
///
/// [today] is injected — never `DateTime.now()` — so this stays deterministic
/// and offline, matching the rest of `core`.
///
/// Returns `null` when there is no safe anchor to draw a wheel from, so the
/// caller can show an honest placeholder instead of a fabricated phase:
/// no [cycle] or [prediction] yet, the cycle is a likely-missed-entry gap
/// ([Cycle.isLikelyGap]) or a pregnancy gap ([Cycle.isPregnancyGap]), the
/// period's start is after [today] (a future-dated entry), or the predicted
/// fertile window doesn't actually sit after the period (a degenerate
/// estimate from a very short or irregular history).
CyclePhase? currentCyclePhase({
  required Cycle? cycle,
  required CyclePrediction? prediction,
  required DateTime today,
}) {
  if (cycle == null || prediction == null) return null;
  if (cycle.isLikelyGap || cycle.isPregnancyGap) return null;

  final day = dateOnly(today);
  final periodStart = cycle.periodStart;
  if (day.isBefore(periodStart)) return null;

  // While the period is still open (no end logged), draw it running through
  // today rather than guessing when it will end.
  final menstrualEnd = cycle.periodEnd ?? day;

  final fertile = prediction.fertileWindow;
  if (!fertile.start.isAfter(menstrualEnd)) return null;

  final lutealStart = addDays(fertile.end, 1);
  final lutealEnd = prediction.nextPeriodExpected.isAfter(fertile.end)
      ? prediction.nextPeriodExpected
      : lutealStart;

  final segments = [
    CyclePhaseSegment(
      kind: CyclePhaseKind.menstrual,
      start: periodStart,
      end: menstrualEnd,
    ),
    CyclePhaseSegment(
      kind: CyclePhaseKind.follicular,
      start: addDays(menstrualEnd, 1),
      end: addDays(fertile.start, -1),
    ),
    CyclePhaseSegment(
      kind: CyclePhaseKind.ovulatory,
      start: fertile.start,
      end: fertile.end,
    ),
    CyclePhaseSegment(
      kind: CyclePhaseKind.luteal,
      start: lutealStart,
      end: lutealEnd,
    ),
  ];

  final index = segments.indexWhere((s) => s.contains(day));
  return CyclePhase(
    today: day,
    segments: segments,
    // Not found means today is past every segment — overdue. Land on the
    // last one (luteal): still waiting on the period, not a new phase.
    currentIndex: index == -1 ? segments.length - 1 : index,
  );
}
