import 'dart:math' as math;

import '../date_math.dart';
import '../prediction/predictor.dart';
import 'synthetic_history.dart';

/// One correction-response probe: a recent logged period-start is mis-logged by
/// a few days, then corrected back to the truth, and the [Predictor] is asked
/// for a forecast in **both** states. Measures the §9(1) property — does fixing
/// a date visibly change the prediction? — without ever calling `DateTime.now()`.
class CorrectionResponsePoint {
  CorrectionResponsePoint({
    required this.asOf,
    required this.mislogOffsetDays,
    required this.actualNextStart,
    required this.predictionMislogged,
    required this.predictionCorrected,
  });

  /// Injected `today` for both calls — the day after the (unchanged) anchor.
  final DateTime asOf;

  /// Signed days the probed boundary was moved before being corrected.
  final int mislogOffsetDays;

  /// The period start that actually came next (ground truth).
  final DateTime actualNextStart;

  /// Forecast with the mis-logged history / with the corrected history.
  final CyclePrediction? predictionMislogged;
  final CyclePrediction? predictionCorrected;

  bool get scored => predictionMislogged != null && predictionCorrected != null;

  /// Whole days the expected date moved between the mis-logged and corrected
  /// forecasts — how visibly the engine reacts to the fix. `null` if unscored.
  int? get visibleEffectDays => !scored
      ? null
      : daysBetween(
          predictionMislogged!.nextPeriodExpected,
          predictionCorrected!.nextPeriodExpected,
        ).abs();

  int? get _absErrMislogged => predictionMislogged == null
      ? null
      : daysBetween(
          actualNextStart,
          predictionMislogged!.nextPeriodExpected,
        ).abs();

  int? get _absErrCorrected => predictionCorrected == null
      ? null
      : daysBetween(
          actualNextStart,
          predictionCorrected!.nextPeriodExpected,
        ).abs();

  /// Positive = correcting the date improved accuracy; negative = it hurt.
  int? get correctionGainDays =>
      !scored ? null : _absErrMislogged! - _absErrCorrected!;
}

/// The full correction-response replay of one history through one [Predictor].
class CorrectionResponseRun {
  CorrectionResponseRun({required this.label, required this.points});

  final String label;
  final List<CorrectionResponsePoint> points;

  Iterable<CorrectionResponsePoint> get scored => points.where((p) => p.scored);

  int get scoredCount => scored.length;

  /// Mean |Δ expected date| across scored probes — the headline number: v2 is
  /// clearly above zero here, v1 sits near it.
  double? get meanVisibleEffectDays =>
      _mean([for (final p in scored) p.visibleEffectDays!.toDouble()]);

  /// Mean accuracy change from applying the correction. Should be ≥ 0 — a fix
  /// must not make the forecast worse on average.
  double? get meanCorrectionGainDays =>
      _mean([for (final p in scored) p.correctionGainDays!.toDouble()]);

  /// Largest single |Δ expected date| — used to check the response is bounded
  /// (no over-reaction to a small mis-log).
  int get maxVisibleEffectDays => scored.isEmpty
      ? 0
      : scored.map((p) => p.visibleEffectDays!).reduce(math.max);
}

/// Replay [periodStarts] (ascending); at each decision point mis-log one recent
/// boundary by ±[mislogOffsetDays], predict, then correct it and predict again.
///
/// [boundaryFromEnd] picks which recent start to disturb, counting back from the
/// anchor (`1` = the boundary between the last two completed cycles — the anchor
/// itself is left intact, so v1's fixed anchor cannot mask the effect). The
/// offset sign alternates by decision point so a consistent bias cannot creep
/// into [CorrectionResponseRun.meanCorrectionGainDays].
CorrectionResponseRun runCorrectionResponse({
  required List<DateTime> periodStarts,
  required Predictor predictor,
  int mislogOffsetDays = 3,
  int boundaryFromEnd = 1,
  int minCompletedCycles = 3,
  String label = 'correction-response',
}) {
  assert(mislogOffsetDays > 0, 'offset is a magnitude; sign is alternated');
  assert(boundaryFromEnd >= 1, 'do not disturb the anchor itself');
  final starts = [for (final d in periodStarts) dateOnly(d)]..sort();

  final points = <CorrectionResponsePoint>[];
  for (var k = minCompletedCycles; k <= starts.length - 2; k++) {
    final known = starts.sublist(0, k + 1);
    final targetIdx = known.length - 1 - boundaryFromEnd;
    if (targetIdx <= 0) continue;

    final signed = k.isEven ? mislogOffsetDays : -mislogOffsetDays;
    final moved = addDays(known[targetIdx], signed);

    // Skip if the mis-log would reorder the logged starts.
    if (!moved.isAfter(known[targetIdx - 1]) ||
        !moved.isBefore(known[targetIdx + 1])) {
      continue;
    }

    final mislogged = [...known]..[targetIdx] = moved;

    final anchor = known.last;
    final asOf = addDays(anchor, 1);

    CyclePrediction? run(List<DateTime> s) =>
        predictor.predict(cycles: cyclesFromStarts(s), today: asOf);

    points.add(
      CorrectionResponsePoint(
        asOf: asOf,
        mislogOffsetDays: signed,
        actualNextStart: starts[k + 1],
        predictionMislogged: run(mislogged),
        predictionCorrected: run(known),
      ),
    );
  }

  return CorrectionResponseRun(label: label, points: points);
}

/// Convenience: correction-response replay of a generated [SyntheticHistory].
CorrectionResponseRun runCorrectionResponseOn(
  SyntheticHistory history, {
  required Predictor predictor,
  int mislogOffsetDays = 3,
  int boundaryFromEnd = 1,
  int minCompletedCycles = 3,
}) => runCorrectionResponse(
  periodStarts: history.periodStarts,
  predictor: predictor,
  mislogOffsetDays: mislogOffsetDays,
  boundaryFromEnd: boundaryFromEnd,
  minCompletedCycles: minCompletedCycles,
  label: history.label,
);

double? _mean(List<double> xs) =>
    xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
