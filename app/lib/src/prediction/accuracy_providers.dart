import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../period/period_providers.dart';
import 'prediction_providers.dart';

/// The result of replaying the user's own logged period history through the
/// **production** predictor (p3.5).
///
/// A plain value object — every figure comes straight from the core
/// [BacktestMetrics]; nothing here is fabricated or smoothed. `null` figures
/// mean "not enough scored points to compute", which the screen renders as a
/// keep-logging prompt rather than a number.
class AccuracyReport {
  const AccuracyReport({
    required this.scoredPoints,
    required this.meanAbsErrorDays,
    required this.medianAbsErrorDays,
    required this.coverage,
    required this.perDecisionAbsErrorDays,
  });

  /// How many past estimates were scored against a real next period — the
  /// sample size shown alongside every metric.
  final int scoredPoints;

  /// Mean / median absolute period-start error, in days. `null` when nothing
  /// scored.
  final double? meanAbsErrorDays;
  final double? medianAbsErrorDays;

  /// Fraction of scored estimates whose real start fell inside the predicted
  /// range. `null` when nothing scored.
  final double? coverage;

  /// Absolute error (days) for each scored estimate, oldest first — the
  /// sparkline series.
  final List<int> perDecisionAbsErrorDays;

  /// Below this many scored points there is not enough signal to show a number.
  static const int minScoredPoints = 3;

  bool get hasEnough => scoredPoints >= minScoredPoints;
}

/// Runs the whole-history backtest on demand.
///
/// `autoDispose` so it re-runs each time the accuracy screen opens and is freed
/// when it closes. Reads only the local `periods` stream and the production
/// [predictorProvider]; it performs **no** I/O of its own — no network, no
/// writes — so post-p3.6 this automatically reports the adaptive engine.
final accuracyReportProvider = FutureProvider.autoDispose<AccuracyReport>((
  ref,
) async {
  final periods = await ref.watch(periodsProvider.future);
  final predictor = ref.watch(predictorProvider);

  final starts = [for (final p in periods) p.startDate]..sort();

  final run = runBacktest(
    periodStarts: starts,
    predictor: predictor,
    label: 'on-device',
    minCompletedCycles: 1,
  );
  final metrics = BacktestMetrics.of(run);

  return AccuracyReport(
    scoredPoints: metrics.scoredPoints,
    meanAbsErrorDays: metrics.meanAbsErrorDays,
    medianAbsErrorDays: metrics.medianAbsErrorDays,
    coverage: metrics.coverage,
    perDecisionAbsErrorDays: [for (final p in run.scored) p.absErrorDays!],
  );
});
