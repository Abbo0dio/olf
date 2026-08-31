import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

/// The fixed **v1 reference** the Phase 3 exit gate compares against:
/// `RobustPredictor` (p1.4) replayed through the p3.1 harness on each seeded
/// synthetic profile.
///
/// Recorded so p3.2's adaptive engine has a concrete bar to beat on the
/// non-regular profiles, and so an accidental regression in `RobustPredictor`
/// is caught. Generated with seed 42, Dart's seeded `Random` (a stable PRNG);
/// tolerances absorb unrelated refactors, not a real behaviour change. If the
/// engine legitimately changes, re-run and update this table in the same PR.
///
/// v1 baseline — period-start error, in days (seed 42):
///
/// | profile        | scored | no-pred | MAE  | median AE | coverage | mean range | ovulation MAE | snowball |
/// |----------------|:------:|:-------:|:----:|:---------:|:--------:|:----------:|:-------------:|:-------:|
/// | regular        |   23   |    0    | 0.87 |    1.0    |   0.957  |    3.57    |      1.74     |    –    |
/// | irregular      |   23   |    0    | 4.39 |    4.0    |   0.739  |   13.96    |      5.00     |    –    |
/// | pcos           |   23   |    0    | 7.22 |    5.0    |   0.565  |   20.35    |      7.48     |  1.108  |
/// | perimenopause  |   23   |    0    | 5.91 |    5.0    |   0.609  |   14.04    |      6.04     |  1.071  |
/// | postpartum     |   16   |    1    | 5.06 |    4.0    |   0.688  |   13.50    |      5.56     |    –    |
void main() {
  const seed = 42;

  const baseline = <String, ({double mae, double medianAe, double coverage})>{
    'regular': (mae: 0.87, medianAe: 1.0, coverage: 0.957),
    'irregular': (mae: 4.39, medianAe: 4.0, coverage: 0.739),
    'pcos': (mae: 7.22, medianAe: 5.0, coverage: 0.565),
    'perimenopause': (mae: 5.91, medianAe: 5.0, coverage: 0.609),
    'postpartum': (mae: 5.06, medianAe: 4.0, coverage: 0.688),
  };

  for (final history in SyntheticHistories.all(seed: seed)) {
    test('v1 baseline is stable — ${history.label}', () {
      final run = runBacktestOn(history, predictor: const RobustPredictor());
      final m = BacktestMetrics.of(run);

      // ignore: avoid_print
      print('v1 baseline ${history.label}: ${m.toRow()}');

      final want = baseline[history.label]!;
      expect(m.meanAbsErrorDays, closeTo(want.mae, 0.5));
      expect(m.medianAbsErrorDays, closeTo(want.medianAe, 1.0));
      expect(m.coverage, closeTo(want.coverage, 0.08));
    });
  }

  test('v1 is much worse on non-regular cycles than on regular ones', () {
    BacktestMetrics run(SyntheticHistory h) => BacktestMetrics.of(
      runBacktestOn(h, predictor: const RobustPredictor()),
    );

    final regular = run(SyntheticHistories.regular(seed: seed));
    for (final h in [
      SyntheticHistories.irregular(seed: seed),
      SyntheticHistories.pcos(seed: seed),
      SyntheticHistories.perimenopause(seed: seed),
      SyntheticHistories.postpartum(seed: seed),
    ]) {
      expect(
        run(h).meanAbsErrorDays,
        greaterThan(regular.meanAbsErrorDays! * 2),
        reason: '${h.label} should be at least 2x worse than regular for v1',
      );
    }
  });

  test(
    'v1 has no anti-snowball logic — where defined, ratio is around/above 1',
    () {
      for (final label in ['pcos', 'perimenopause']) {
        final h = SyntheticHistories.all(
          seed: seed,
        ).firstWhere((h) => h.label == label);
        final s = BacktestMetrics.of(
          runBacktestOn(h, predictor: const RobustPredictor()),
        ).snowball;
        expect(
          s,
          isNotNull,
          reason: '$label should have enough outlier points',
        );
        expect(
          s!.ratio,
          greaterThan(0.9),
          reason: 'v1 does not dampen post-outlier error on $label',
        );
      }
    },
  );
}
