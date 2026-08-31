import '../date_math.dart';
import '../prediction/predictor.dart';
import '../prediction/robust_predictor.dart' show fertileDaysBeforeOvulation;
import 'synthetic_history.dart';

/// One historical decision point: what a [Predictor] said when asked right
/// after a given period start, and what actually happened next.
class BacktestPoint {
  BacktestPoint({
    required this.asOf,
    required this.completedCycles,
    required this.mostRecentCycleLength,
    required this.actualNextStart,
    required this.prediction,
    this.actualOvulation,
  });

  /// The injected `today` for this call — the day after the most recent logged
  /// period start (the realistic "what's my next period?" moment).
  final DateTime asOf;

  /// Completed cycles the predictor could see at [asOf].
  final int completedCycles;

  /// Length (days) of the most recent completed cycle in the known history, or
  /// `null` if there was none. Used by the snowball metric to spot a call made
  /// right after an anomalous month.
  final int? mostRecentCycleLength;

  /// The period start that actually came next (ground truth).
  final DateTime actualNextStart;

  /// True ovulation day for the cycle opened by the anchor, when known.
  final DateTime? actualOvulation;

  /// What the predictor returned — `null` when the history was too thin.
  final CyclePrediction? prediction;

  bool get hasPrediction => prediction != null;

  /// Signed days: positive means the predicted start was **later** than the
  /// real one (predicted the period would be late); negative means earlier.
  int? get signedErrorDays => prediction == null
      ? null
      : daysBetween(actualNextStart, prediction!.nextPeriodExpected);

  int? get absErrorDays => signedErrorDays?.abs();

  /// Did the actual start fall inside the predicted range?
  bool? get covered => prediction?.nextPeriod.contains(actualNextStart);

  int? get rangeWidthDays => prediction?.nextPeriod.lengthInDays;

  /// Absolute ovulation-day error, when both a prediction and a truth signal
  /// exist. The predicted ovulation day is recovered from the fertile window
  /// (`fertileWindow.start + fertileDaysBeforeOvulation`).
  int? get ovulationAbsErrorDays {
    final p = prediction;
    final truth = actualOvulation;
    if (p == null || truth == null) return null;
    final predictedOvulation = addDays(
      p.fertileWindow.start,
      fertileDaysBeforeOvulation,
    );
    return daysBetween(truth, predictedOvulation).abs();
  }
}

/// The full replay of one history through one [Predictor].
class BacktestRun {
  BacktestRun({required this.label, required this.points});

  final String label;
  final List<BacktestPoint> points;

  Iterable<BacktestPoint> get scored => points.where((p) => p.hasPrediction);

  int get scoredCount => scored.length;
  int get noPredictionCount => points.length - scoredCount;
}

/// Replay [periodStarts] (ascending) chronologically through [predictor].
///
/// At each cutoff `k` (from [minCompletedCycles] to the second-to-last start),
/// the predictor is given only `periodStarts[0..k]` — `k` completed cycles plus
/// the open one — with `today` = the day after `periodStarts[k]`. Its forecast
/// is scored against `periodStarts[k + 1]`.
///
/// [ovulationByStart] is optional truth for the ovulation metric; omit it and
/// [BacktestPoint.ovulationAbsErrorDays] is simply `null` everywhere.
BacktestRun runBacktest({
  required List<DateTime> periodStarts,
  required Predictor predictor,
  String label = 'backtest',
  int minCompletedCycles = 1,
  Map<DateTime, DateTime> ovulationByStart = const {},
}) {
  assert(minCompletedCycles >= 1, 'need at least one completed cycle to score');
  final starts = [for (final d in periodStarts) dateOnly(d)]..sort();

  final points = <BacktestPoint>[];
  for (var k = minCompletedCycles; k <= starts.length - 2; k++) {
    final known = starts.sublist(0, k + 1);
    final anchor = known.last;
    final asOf = addDays(anchor, 1);
    final cycles = cyclesFromStarts(known);

    final prediction = predictor.predict(cycles: cycles, today: asOf);

    points.add(
      BacktestPoint(
        asOf: asOf,
        completedCycles: k,
        mostRecentCycleLength: k >= 1
            ? daysBetween(known[k - 1], known[k])
            : null,
        actualNextStart: starts[k + 1],
        actualOvulation: ovulationByStart[anchor],
        prediction: prediction,
      ),
    );
  }

  return BacktestRun(label: label, points: points);
}

/// Convenience: replay a generated [SyntheticHistory].
BacktestRun runBacktestOn(
  SyntheticHistory history, {
  required Predictor predictor,
  int minCompletedCycles = 1,
}) => runBacktest(
  periodStarts: history.periodStarts,
  predictor: predictor,
  label: history.label,
  minCompletedCycles: minCompletedCycles,
  ovulationByStart: history.ovulationByStart,
);
