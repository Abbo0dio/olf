import '../cycle/cycle.dart';
import '../date_math.dart';
import '../db/app_database.dart';
import '../prediction/date_range.dart';
import '../prediction/predictor.dart';
import '../prediction/robust_predictor.dart'
    show fertileDaysAfterOvulation, fertileDaysBeforeOvulation;
import 'passive_phase_inference.dart';

/// Wraps another [Predictor] and lets the **passive temperature signal** refine
/// its output — as one more observation, never a replacement (p8.5).
///
/// The [Predictor] interface is unchanged. This decorator:
///
///  * delegates the whole forecast to [inner];
///  * when [inferPassivePhase] confirms a post-ovulatory thermal shift **in the
///    current open cycle, on or before `today`**, re-anchors only
///    [CyclePrediction.fertileWindow] on that observed ovulation day;
///  * leaves [CyclePrediction.nextPeriod], [CyclePrediction.nextPeriodExpected],
///    [CyclePrediction.confidence], [CyclePrediction.basedOnCycles] and
///    [CyclePrediction.status] **exactly** as [inner] produced them — so the
///    next-period error and calibration a backtest measures cannot regress.
///
/// With no passive temperature rows, or no confirmed shift, the result is
/// **byte-identical** to `inner.predict(...)` — the engine degrades to exactly
/// its prior behaviour. A user correction (an edited period, a logged flow) is
/// upstream of this: it changes [cycles] / [temperatures], which re-runs the
/// whole pipeline, so a human's entry always wins.
///
/// `today` is injected end-to-end; there is no `DateTime.now()` here.
class PassiveInformedPredictor implements Predictor {
  const PassiveInformedPredictor({
    required Predictor inner,
    required Iterable<BbtEntry> temperatures,
    Iterable<PassiveHrvSample> hrv = const [],
    Iterable<PassiveSleepSample> sleep = const [],
  }) : _inner = inner,
       _temperatures = temperatures,
       _hrv = hrv,
       _sleep = sleep;

  final Predictor _inner;
  final Iterable<BbtEntry> _temperatures;
  final Iterable<PassiveHrvSample> _hrv;
  final Iterable<PassiveSleepSample> _sleep;

  @override
  CyclePrediction? predict({
    required List<Cycle> cycles,
    required DateTime today,
  }) {
    final base = _inner.predict(cycles: cycles, today: today);
    if (base == null) return null;

    final estimate = inferPassivePhase(
      temperatures: _temperatures,
      cycles: cycles,
      prediction: base,
      today: today,
      hrv: _hrv,
      sleep: _sleep,
    );
    if (estimate == null ||
        estimate.read != PassivePhaseRead.ovulationLikelyPassed) {
      return base;
    }

    // Only refine when the observed ovulation actually sits in the open cycle
    // and has already happened relative to `today`. A shift detected for an
    // earlier cycle, or dated in the future, does not touch this cycle's window.
    final ovulation = dateOnly(estimate.estimatedOvulation);
    final t = dateOnly(today);
    final cycleStart = cycles.first.periodStart;
    if (ovulation.isBefore(cycleStart) || ovulation.isAfter(t)) return base;

    final refinedWindow = DateRange(
      addDays(ovulation, -fertileDaysBeforeOvulation),
      addDays(ovulation, fertileDaysAfterOvulation),
    );
    if (refinedWindow == base.fertileWindow) return base;

    return base.copyWith(fertileWindow: refinedWindow);
  }
}
