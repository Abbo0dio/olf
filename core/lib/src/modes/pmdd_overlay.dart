import 'package:meta/meta.dart';

import '../cycle/cycle.dart';
import '../cycle/cycle_phase.dart';
import '../date_math.dart';
import '../db/tables.dart';
import '../symptom/symptom_severity.dart';
import 'cycle_phase_correlation.dart';

/// The rating at or above which a PMDD day counts as **notable** — the
/// luteal-rise signal. Milder days are still logged, they just don't drive the
/// phase read.
const SymptomSeverity pmddNotableFrom = SymptomSeverity.moderate;

/// One calendar day's PMDD rating: a value on the shared [SymptomSeverity]
/// scale for each rated [PmddSymptom] (`none` included — "rated, nothing
/// today"). The app builds these from the `pmdd_ratings` rows for a day.
@immutable
class PmddDayRating {
  const PmddDayRating({required this.date, required this.items});

  final DateTime date;
  final Map<PmddSymptom, SymptomSeverity> items;

  /// The highest rating across the day's items (`0` when nothing is rated).
  int get peakRank => items.isEmpty
      ? 0
      : items.values.map((s) => s.rank).reduce((a, b) => a > b ? a : b);

  /// Whether the day's peak reaches [pmddNotableFrom].
  bool get isNotable => peakRank >= pmddNotableFrom.rank;
}

/// A plain-language read of how the ratings sit against cycle phase. **Never** a
/// DRSP score, a diagnostic threshold, or a "you have PMDD" claim (§9(12)) — a
/// short descriptive sentence at most.
enum PmddLutealRead {
  /// Fewer than [correlationMinCompletedCycles] cycles of history, or fewer
  /// than [correlationMinPlacedDays] notable days placed in a phase.
  notEnoughData,

  /// Enough data, but the notable days do not concentrate in the luteal phase.
  noClearLutealPattern,

  /// Notable days show up markedly more in the luteal phase — the pattern PMDD
  /// is defined by.
  runsHigherInLuteal,
}

/// The PMDD cycle-overlay: notable-rating days and all rated days bucketed by
/// cycle phase across the derived [cycles], plus a descriptive luteal read.
@immutable
class PmddOverlay {
  const PmddOverlay({
    required this.notableDaysByPhase,
    required this.ratedDaysByPhase,
    required this.enoughData,
    required this.lutealRead,
  });

  /// Notable days (peak rating ≥ [pmddNotableFrom]) that fell inside a phase
  /// segment, split by [CyclePhaseKind] — fed straight to `CorrelationChart`.
  final Map<CyclePhaseKind, int> notableDaysByPhase;

  /// Every rated day that fell inside a phase segment, split by phase — the
  /// context for the notable count ("you rated N luteal days").
  final Map<CyclePhaseKind, int> ratedDaysByPhase;

  /// Whether there is enough history + enough notable days to offer a read.
  final bool enoughData;

  final PmddLutealRead lutealRead;

  /// Notable days that landed inside any phase segment.
  int get notablePlacedDays =>
      notableDaysByPhase.values.fold(0, (s, n) => s + n);

  @override
  bool operator ==(Object other) =>
      other is PmddOverlay &&
      _sameMap(other.notableDaysByPhase, notableDaysByPhase) &&
      _sameMap(other.ratedDaysByPhase, ratedDaysByPhase) &&
      other.enoughData == enoughData &&
      other.lutealRead == lutealRead;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(
      CyclePhaseKind.values.map((k) => notableDaysByPhase[k] ?? 0),
    ),
    Object.hashAll(CyclePhaseKind.values.map((k) => ratedDaysByPhase[k] ?? 0)),
    enoughData,
    lutealRead,
  );
}

bool _sameMap(Map<CyclePhaseKind, int> a, Map<CyclePhaseKind, int> b) {
  for (final k in CyclePhaseKind.values) {
    if ((a[k] ?? 0) != (b[k] ?? 0)) return false;
  }
  return true;
}

const Map<CyclePhaseKind, int> _zeroByPhase = {
  CyclePhaseKind.menstrual: 0,
  CyclePhaseKind.follicular: 0,
  CyclePhaseKind.ovulatory: 0,
  CyclePhaseKind.luteal: 0,
};

/// Derive the PMDD overlay from [ratings] and the derived [cycles] as of
/// [today] (injected — never `DateTime.now()`).
///
/// Alignment maths reuse the p7.4 [cyclePhaseCorrelations] core **unchanged**:
/// each rated day is one `PhaseEvent`, so a short cycle, a likely-gap cycle or
/// the open current cycle are all handled exactly as they are there — a day
/// that does not fall inside a placed phase segment simply is not counted.
/// Deterministic: identical inputs give an identical result.
PmddOverlay pmddOverlay({
  required Iterable<PmddDayRating> ratings,
  required Iterable<Cycle> cycles,
  required DateTime today,
}) {
  final cyclesList = cycles.toList();
  final events = <PhaseEvent>[];
  for (final r in ratings) {
    if (r.items.isEmpty) continue;
    final day = dateOnly(r.date);
    events.add(PhaseEvent(day: day, category: 'rated'));
    if (r.isNotable) events.add(PhaseEvent(day: day, category: 'notable'));
  }

  final correlations = cyclePhaseCorrelations(
    events: events,
    cycles: cyclesList,
    today: today,
  );

  PhaseCorrelation? byCategory(String category) {
    for (final c in correlations) {
      if (c.category == category) return c;
    }
    return null;
  }

  final notable = byCategory('notable');
  final rated = byCategory('rated');

  final PmddLutealRead read;
  if (notable == null || !notable.enoughData) {
    read = PmddLutealRead.notEnoughData;
  } else if (notable.showsUpMostIn == CyclePhaseKind.luteal) {
    read = PmddLutealRead.runsHigherInLuteal;
  } else {
    read = PmddLutealRead.noClearLutealPattern;
  }

  return PmddOverlay(
    notableDaysByPhase: notable?.daysByPhase ?? _zeroByPhase,
    ratedDaysByPhase: rated?.daysByPhase ?? _zeroByPhase,
    enoughData: notable?.enoughData ?? false,
    lutealRead: read,
  );
}
