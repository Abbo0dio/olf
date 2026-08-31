import 'backtest_harness.dart';

/// How the snowball check is parameterised.
class SnowballConfig {
  const SnowballConfig({
    this.outlierDeviationDays = 10,
    this.minPointsEitherSide = 2,
  });

  /// A completed cycle counts as an "outlier" when its length is more than this
  /// many days from the run's median completed-cycle length.
  final int outlierDeviationDays;

  /// The ratio is only reported when there are at least this many scored points
  /// both right-after-an-outlier and not.
  final int minPointsEitherSide;
}

/// Did predictions made **right after an anomalous cycle** do worse than the
/// run as a whole? [ratio] > 1 means an outlier month degraded the next
/// forecast — a snowball.
class SnowballMetric {
  const SnowballMetric({
    required this.baselineMeanAbsError,
    required this.postOutlierMeanAbsError,
    required this.postOutlierPoints,
    required this.otherPoints,
  });

  final double baselineMeanAbsError;
  final double postOutlierMeanAbsError;
  final int postOutlierPoints;
  final int otherPoints;

  /// `null` when there were too few points on one side, or the baseline error
  /// is zero.
  double? get ratio => baselineMeanAbsError == 0
      ? null
      : postOutlierMeanAbsError / baselineMeanAbsError;
}

/// Accuracy of one [BacktestRun]. All error figures are in whole days and
/// computed over the **scored** points only (a `null` prediction is counted in
/// [noPredictionPoints], never as a zero-error hit).
class BacktestMetrics {
  const BacktestMetrics({
    required this.label,
    required this.totalPoints,
    required this.scoredPoints,
    required this.noPredictionPoints,
    required this.meanAbsErrorDays,
    required this.medianAbsErrorDays,
    required this.coverage,
    required this.meanRangeWidthDays,
    required this.ovulationMeanAbsErrorDays,
    required this.snowball,
  });

  final String label;
  final int totalPoints;
  final int scoredPoints;
  final int noPredictionPoints;

  /// Mean / median absolute period-start error. `null` when nothing scored.
  final double? meanAbsErrorDays;
  final double? medianAbsErrorDays;

  /// Fraction (0..1) of scored points whose actual start fell inside the
  /// predicted range — the calibration signal. `null` when nothing scored.
  final double? coverage;

  /// Mean predicted-range width (days), for context on [coverage].
  final double? meanRangeWidthDays;

  /// Mean absolute ovulation-day error where a truth signal was supplied;
  /// `null` when none was.
  final double? ovulationMeanAbsErrorDays;

  final SnowballMetric? snowball;

  static BacktestMetrics of(
    BacktestRun run, {
    SnowballConfig snowball = const SnowballConfig(),
  }) {
    final scored = run.scored.toList();
    final absErrors = [for (final p in scored) p.absErrorDays!.toDouble()];
    final ovErrors = [
      for (final p in scored)
        if (p.ovulationAbsErrorDays != null)
          p.ovulationAbsErrorDays!.toDouble(),
    ];
    final widths = [
      for (final p in scored)
        if (p.rangeWidthDays != null) p.rangeWidthDays!.toDouble(),
    ];

    return BacktestMetrics(
      label: run.label,
      totalPoints: run.points.length,
      scoredPoints: scored.length,
      noPredictionPoints: run.noPredictionCount,
      meanAbsErrorDays: _mean(absErrors),
      medianAbsErrorDays: _median(absErrors),
      coverage: scored.isEmpty
          ? null
          : scored.where((p) => p.covered == true).length / scored.length,
      meanRangeWidthDays: _mean(widths),
      ovulationMeanAbsErrorDays: _mean(ovErrors),
      snowball: _snowball(run, snowball),
    );
  }

  Map<String, Object?> toRow() => {
    'label': label,
    'scored': scoredPoints,
    'noPrediction': noPredictionPoints,
    'maeDays': _round(meanAbsErrorDays),
    'medianAeDays': _round(medianAbsErrorDays),
    'coverage': _round(coverage),
    'meanRangeDays': _round(meanRangeWidthDays),
    'ovulationMaeDays': _round(ovulationMeanAbsErrorDays),
    'snowballRatio': _round(snowball?.ratio),
  };

  @override
  String toString() => toRow().toString();
}

SnowballMetric? _snowball(BacktestRun run, SnowballConfig cfg) {
  final scored = run.scored.toList();
  if (scored.isEmpty) return null;

  final lengths = [
    for (final p in scored)
      if (p.mostRecentCycleLength != null) p.mostRecentCycleLength!.toDouble(),
  ];
  final medianLen = _median(lengths);
  if (medianLen == null) return null;

  final postOutlier = <double>[];
  final other = <double>[];
  for (final p in scored) {
    final len = p.mostRecentCycleLength;
    final err = p.absErrorDays!.toDouble();
    if (len != null && (len - medianLen).abs() > cfg.outlierDeviationDays) {
      postOutlier.add(err);
    } else {
      other.add(err);
    }
  }

  if (postOutlier.length < cfg.minPointsEitherSide ||
      other.length < cfg.minPointsEitherSide) {
    return null;
  }

  return SnowballMetric(
    baselineMeanAbsError: _mean([...postOutlier, ...other])!,
    postOutlierMeanAbsError: _mean(postOutlier)!,
    postOutlierPoints: postOutlier.length,
    otherPoints: other.length,
  );
}

double? _mean(List<double> xs) =>
    xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;

double? _median(List<double> xs) {
  if (xs.isEmpty) return null;
  final s = [...xs]..sort();
  final mid = s.length ~/ 2;
  return s.length.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

double? _round(double? x) =>
    x == null ? null : (x * 1000).roundToDouble() / 1000;

/// Exposed for callers that want the same rounding in their own output.
double roundTo3(double x) => (x * 1000).roundToDouble() / 1000;
