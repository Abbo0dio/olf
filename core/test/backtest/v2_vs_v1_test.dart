import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

/// p3.2 exit check: [AdaptivePredictor] (v2) vs [RobustPredictor] (v1) through
/// the p3.1 harness, on the reframed acceptance bar (orchestrator decision
/// 2026-08-31 — "trust first"):
///
///  * **Point error (MAE):** v2 *beats* v1 on `pcos` and `postpartum`; v2 is
///    within noise (≤ +3 %) of v1 on `regular`, `irregular`, `perimenopause` —
///    a recency-weighted robust median is already near-MAE-optimal there.
///  * **Calibration:** coverage ≥ 0.80 on `regular` / `irregular` / `postpartum`;
///    on `pcos` / `perimenopause` v2 coverage beats v1's by a clear margin and
///    clears a 0.68 floor (an absolute 0.80 there would need a useless ±13-day
///    band), and the wide-range predictions are marked **not high** confidence.
///  * **Anti-snowball:** v2 mean snowball ratio ≤ v1's (p3.4). The full
///    guarantee — per-profile, aggregate, in- *and* out-of-sample, plus a
///    single-injected-outlier recovery bound — lives in `anti_snowball_test`;
///    this file keeps a light in-sample smoke.
///
/// Aggregated over a fixed seed set so per-seed sampling noise cannot flip it.
/// **Out-of-sample:** the calibration floors are re-checked on a held-out seed
/// range ([heldOutSeeds]) the p3.2 constants were never tuned against.
void main() {
  const v1 = RobustPredictor();
  const v2 = AdaptivePredictor();
  final seeds = List<int>.generate(20, (i) => i + 1);
  final heldOutSeeds = List<int>.generate(50, (i) => i + 200);
  const profiles = [
    'regular',
    'irregular',
    'pcos',
    'perimenopause',
    'postpartum',
  ];

  List<SyntheticHistory> setsFor(int seed) => [
    SyntheticHistories.regular(seed: seed),
    SyntheticHistories.irregular(seed: seed),
    SyntheticHistories.pcos(seed: seed),
    SyntheticHistories.perimenopause(seed: seed),
    SyntheticHistories.postpartum(seed: seed),
  ];

  /// Mean of [f] over [over] (default: the in-sample [seeds]) for profile [i].
  double mean(
    int i,
    double? Function(BacktestMetrics) f,
    Predictor p, {
    List<int>? over,
  }) {
    var sum = 0.0;
    var n = 0;
    for (final seed in over ?? seeds) {
      final v = f(
        BacktestMetrics.of(runBacktestOn(setsFor(seed)[i], predictor: p)),
      );
      if (v != null) {
        sum += v;
        n++;
      }
    }
    return sum / n;
  }

  double meanSnowball(int i, Predictor p) =>
      mean(i, (m) => m.snowball?.ratio, p);

  test('v2 vs v1 — reframed bar (table printed)', () {
    // ignore: avoid_print
    print(
      '${'profile'.padRight(14)} '
      '${'v1 MAE'.padLeft(8)} ${'v2 MAE'.padLeft(8)} '
      '${'v1 cov'.padLeft(8)} ${'v2 cov'.padLeft(8)} '
      '${'v1 snow'.padLeft(8)} ${'v2 snow'.padLeft(8)}',
    );
    for (var i = 0; i < profiles.length; i++) {
      final v1Mae = mean(i, (m) => m.meanAbsErrorDays, v1);
      final v2Mae = mean(i, (m) => m.meanAbsErrorDays, v2);
      final v1Cov = mean(i, (m) => m.coverage, v1);
      final v2Cov = mean(i, (m) => m.coverage, v2);
      // ignore: avoid_print
      print(
        '${profiles[i].padRight(14)} '
        '${v1Mae.toStringAsFixed(2).padLeft(8)} '
        '${v2Mae.toStringAsFixed(2).padLeft(8)} '
        '${v1Cov.toStringAsFixed(2).padLeft(8)} '
        '${v2Cov.toStringAsFixed(2).padLeft(8)} '
        '${meanSnowball(i, v1).toStringAsFixed(2).padLeft(8)} '
        '${meanSnowball(i, v2).toStringAsFixed(2).padLeft(8)}',
      );
    }
  });

  group('point error (MAE)', () {
    test('v2 beats v1 on pcos and postpartum', () {
      for (final label in ['pcos', 'postpartum']) {
        final i = profiles.indexOf(label);
        final v1Mae = mean(i, (m) => m.meanAbsErrorDays, v1);
        final v2Mae = mean(i, (m) => m.meanAbsErrorDays, v2);
        expect(
          v2Mae,
          lessThan(v1Mae),
          reason: '$label: v2 MAE $v2Mae should beat v1 MAE $v1Mae',
        );
      }
    });

    test('v2 is within noise of v1 on regular / irregular / perimenopause', () {
      for (final label in ['regular', 'irregular', 'perimenopause']) {
        final i = profiles.indexOf(label);
        final v1Mae = mean(i, (m) => m.meanAbsErrorDays, v1);
        final v2Mae = mean(i, (m) => m.meanAbsErrorDays, v2);
        expect(
          v2Mae,
          lessThanOrEqualTo(v1Mae * 1.03),
          reason: '$label: v2 MAE $v2Mae must not regress past +3% of $v1Mae',
        );
      }
    });
  });

  group('calibration', () {
    test('coverage ≥ 0.80 on regular / irregular / postpartum', () {
      for (final label in ['regular', 'irregular', 'postpartum']) {
        final i = profiles.indexOf(label);
        expect(
          mean(i, (m) => m.coverage, v2),
          greaterThanOrEqualTo(0.80),
          reason: '$label coverage',
        );
      }
    });

    test(
      'pcos / perimenopause — v2 coverage clearly beats v1, clears 0.68',
      () {
        for (final label in ['pcos', 'perimenopause']) {
          final i = profiles.indexOf(label);
          final v1Cov = mean(i, (m) => m.coverage, v1);
          final v2Cov = mean(i, (m) => m.coverage, v2);
          expect(
            v2Cov,
            greaterThan(v1Cov + 0.10),
            reason: '$label: v2 cov $v2Cov vs v1 cov $v1Cov',
          );
          expect(v2Cov, greaterThanOrEqualTo(0.68), reason: '$label floor');
        }
      },
    );

    test('pcos wide-range predictions are not sold as high confidence', () {
      final i = profiles.indexOf('pcos');
      var high = 0;
      var total = 0;
      for (final seed in seeds) {
        final run = runBacktestOn(setsFor(seed)[i], predictor: v2);
        for (final pt in run.scored) {
          total++;
          if (pt.prediction!.confidence == PredictionConfidence.high) high++;
        }
      }
      expect(high / total, lessThan(0.15));
    });

    test(
      'held-out (seeds 200–249) — the p3.2 calibration floors still hold',
      () {
        // The p3.2 constants (_widthSafety, the coverage-quantile lifts) were
        // tuned on low seed ranges that overlap this file's assertion seeds.
        // Re-check the floors on a range they never saw.
        for (final label in ['regular', 'irregular', 'postpartum']) {
          final i = profiles.indexOf(label);
          expect(
            mean(i, (m) => m.coverage, v2, over: heldOutSeeds),
            greaterThanOrEqualTo(0.80),
            reason: '$label held-out coverage',
          );
        }
        for (final label in ['pcos', 'perimenopause']) {
          final i = profiles.indexOf(label);
          final v1Cov = mean(i, (m) => m.coverage, v1, over: heldOutSeeds);
          final v2Cov = mean(i, (m) => m.coverage, v2, over: heldOutSeeds);
          expect(v2Cov, greaterThan(v1Cov + 0.10), reason: '$label held-out');
          expect(
            v2Cov,
            greaterThanOrEqualTo(0.68),
            reason: '$label held-out floor',
          );
        }
      },
    );

    test('held-out — MAE parity / beat carries out of sample', () {
      for (final label in ['pcos', 'postpartum']) {
        final i = profiles.indexOf(label);
        expect(
          mean(i, (m) => m.meanAbsErrorDays, v2, over: heldOutSeeds),
          lessThan(mean(i, (m) => m.meanAbsErrorDays, v1, over: heldOutSeeds)),
          reason: '$label held-out: v2 must still beat v1',
        );
      }
      for (final label in ['regular', 'irregular', 'perimenopause']) {
        final i = profiles.indexOf(label);
        expect(
          mean(i, (m) => m.meanAbsErrorDays, v2, over: heldOutSeeds),
          lessThanOrEqualTo(
            mean(i, (m) => m.meanAbsErrorDays, v1, over: heldOutSeeds) * 1.03,
          ),
          reason: '$label held-out: v2 must not regress past +3%',
        );
      }
    });
  });

  test('anti-snowball smoke — v2 ≤ v1 + 0.05 per set in-sample', () {
    // The real guarantee (aggregate + per-profile + held-out + single-outlier
    // recovery) is in anti_snowball_test; this is a fast tripwire.
    for (var i = 0; i < profiles.length; i++) {
      final s1 = meanSnowball(i, v1);
      final s2 = meanSnowball(i, v2);
      if (s1.isNaN || s2.isNaN) continue;
      expect(
        s2,
        lessThanOrEqualTo(s1 + 0.05),
        reason: '${profiles[i]}: v2 snowball $s2 vs v1 $s1',
      );
    }
  });
}
