import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

/// p8.5 — the passive-inference layer must not regress the Phase 3 backtester.
///
/// `PassiveInformedPredictor` wraps `AdaptivePredictor` and only ever refines
/// the **current** cycle's fertile window from a confirmed thermal shift. The
/// backtester asks the predictor at `asOf = anchor + 1`, when the open cycle has
/// no post-ovulatory temperature data, so the decorator is a pure pass-through
/// there — this test asserts that: combined MAE, calibration (coverage) and
/// ovulation error are **no worse** than the bare `AdaptivePredictor` on every
/// seeded profile. "No change" is the expected — and acceptable — result
/// (p3.2 discipline).
void main() {
  const baseline = AdaptivePredictor();

  for (final history in SyntheticHistories.all()) {
    test('${history.label}: passive-informed predictor does not regress '
        'the backtest', () {
      final passive = syntheticPassiveTemperature(history);
      final combined = PassiveInformedPredictor(
        inner: baseline,
        temperatures: passive,
      );

      final base = BacktestMetrics.of(
        runBacktestOn(history, predictor: baseline),
      );
      final withPassive = BacktestMetrics.of(
        runBacktestOn(history, predictor: combined),
      );

      expect(withPassive.scoredPoints, base.scoredPoints);

      // MAE: no worse (tiny epsilon for float assembly, though it is exactly
      // equal here by construction).
      expect(
        withPassive.meanAbsErrorDays!,
        lessThanOrEqualTo(base.meanAbsErrorDays! + 1e-9),
        reason: '${history.label}: next-period MAE regressed',
      );

      // Calibration: coverage not lower.
      expect(
        withPassive.coverage!,
        greaterThanOrEqualTo(base.coverage! - 1e-9),
        reason: '${history.label}: coverage regressed',
      );

      // Ovulation error: not worse.
      expect(
        withPassive.ovulationMeanAbsErrorDays!,
        lessThanOrEqualTo(base.ovulationMeanAbsErrorDays! + 1e-9),
        reason: '${history.label}: ovulation MAE regressed',
      );
    });
  }

  test('the decorator is an exact pass-through at every backtest decision '
      'point (regular profile)', () {
    final history = SyntheticHistories.regular();
    final combined = PassiveInformedPredictor(
      inner: baseline,
      temperatures: syntheticPassiveTemperature(history),
    );
    final a = runBacktestOn(history, predictor: baseline);
    final b = runBacktestOn(history, predictor: combined);
    for (var i = 0; i < a.points.length; i++) {
      expect(
        b.points[i].prediction,
        a.points[i].prediction,
        reason: 'point $i diverged',
      );
    }
  });
}
