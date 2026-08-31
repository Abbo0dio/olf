import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

/// **Phase 3 exit gate — one consolidated, reproducible evidence table.**
///
/// p3.6 makes [AdaptivePredictor] (v2) the production `Predictor`. The phase's
/// exit gate is three claims, each already covered in depth by its own file:
///
///  * **Measurable improvement over v1 on the irregular-cycle datasets** —
///    point error + calibration (`v2_vs_v1_test`).
///  * **Corrections demonstrably change output** — a fixed mis-log moves v2's
///    forecast far more than v1's, without hurting accuracy (`correction_response_test`).
///  * **No snowballing** — one anomaly does not poison later forecasts, in- and
///    out-of-sample (`anti_snowball_test`).
///
/// This file ties them together: it prints the single table the p3.6 PR body
/// quotes, and re-asserts the load-bearing inequality from each claim so the
/// table cannot silently drift. It intentionally does **not** re-derive the
/// finer per-profile bounds — those stay in the three source files.
///
/// All figures are aggregated over fixed seed sets so per-seed sampling noise
/// cannot flip the gate. `heldOut` is a seed range the v2 constants were never
/// tuned against.
void main() {
  const v1 = RobustPredictor();
  const v2 = AdaptivePredictor();

  const profiles = [
    'regular',
    'irregular',
    'pcos',
    'perimenopause',
    'postpartum',
  ];

  /// The datasets v2 must *improve* on (the "irregular-cycle datasets" of the
  /// phase goal) vs the ones where v1's flat robust median is already near
  /// optimal and v2 only has to hold parity.
  const improveOn = ['pcos', 'postpartum'];
  const parityOn = ['regular', 'irregular', 'perimenopause'];

  final inSample = List<int>.generate(20, (i) => i + 1);
  final heldOut = List<int>.generate(50, (i) => i + 200);

  List<SyntheticHistory> setsFor(int seed) => [
    SyntheticHistories.regular(seed: seed),
    SyntheticHistories.irregular(seed: seed),
    SyntheticHistories.pcos(seed: seed),
    SyntheticHistories.perimenopause(seed: seed),
    SyntheticHistories.postpartum(seed: seed),
  ];

  /// Mean of [f] over [seeds] for profile [i] under predictor [p]; `null`
  /// samples skipped. `minCC` matches the source file for that metric.
  double mean(
    int i,
    Predictor p,
    List<int> seeds,
    double? Function(BacktestMetrics) f, {
    int minCC = 1,
  }) {
    var sum = 0.0;
    var n = 0;
    for (final seed in seeds) {
      final v = f(
        BacktestMetrics.of(
          runBacktestOn(
            setsFor(seed)[i],
            predictor: p,
            minCompletedCycles: minCC,
          ),
        ),
      );
      if (v != null && !v.isNaN) {
        sum += v;
        n++;
      }
    }
    return n == 0 ? double.nan : sum / n;
  }

  double mae(int i, Predictor p, List<int> seeds) =>
      mean(i, p, seeds, (m) => m.meanAbsErrorDays);
  double cov(int i, Predictor p, List<int> seeds) =>
      mean(i, p, seeds, (m) => m.coverage);

  // The snowball ratio is only meaningful once the forecast is established
  // (matches anti_snowball_test's minCC = 3).
  double snow(int i, Predictor p, List<int> seeds) =>
      mean(i, p, seeds, (m) => m.snowball?.ratio, minCC: 3);

  /// Mean visible forecast shift (days) from a fixed [mislog]-day mis-log, over
  /// [seeds] for profile [i] (matches correction_response_test).
  double correctionEffect(
    int i,
    Predictor p,
    List<int> seeds, {
    int mislog = 3,
  }) {
    var sum = 0.0;
    var n = 0;
    for (final seed in seeds) {
      final e = runCorrectionResponseOn(
        setsFor(seed)[i],
        predictor: p,
        mislogOffsetDays: mislog,
      ).meanVisibleEffectDays;
      if (e != null) {
        sum += e;
        n++;
      }
    }
    return n == 0 ? double.nan : sum / n;
  }

  double aggregateSnowball(Predictor p, List<int> seeds) {
    final defined = <double>[];
    for (var i = 0; i < profiles.length; i++) {
      final s = snow(i, p, seeds);
      if (!s.isNaN) defined.add(s);
    }
    return defined.reduce((a, b) => a + b) / defined.length;
  }

  void printTable(String heading, List<int> seeds) {
    // ignore: avoid_print
    print('\n=== $heading (${seeds.length} seeds) ===');
    // ignore: avoid_print
    print(
      '${'profile'.padRight(14)}'
      '${'MAE v1'.padLeft(9)}${'MAE v2'.padLeft(9)}'
      '${'cov v1'.padLeft(9)}${'cov v2'.padLeft(9)}'
      '${'snow v1'.padLeft(9)}${'snow v2'.padLeft(9)}'
      '${'corr v1'.padLeft(9)}${'corr v2'.padLeft(9)}',
    );
    for (var i = 0; i < profiles.length; i++) {
      // ignore: avoid_print
      print(
        '${profiles[i].padRight(14)}'
        '${mae(i, v1, seeds).toStringAsFixed(2).padLeft(9)}'
        '${mae(i, v2, seeds).toStringAsFixed(2).padLeft(9)}'
        '${cov(i, v1, seeds).toStringAsFixed(2).padLeft(9)}'
        '${cov(i, v2, seeds).toStringAsFixed(2).padLeft(9)}'
        '${snow(i, v1, seeds).toStringAsFixed(2).padLeft(9)}'
        '${snow(i, v2, seeds).toStringAsFixed(2).padLeft(9)}'
        '${correctionEffect(i, v1, seeds).toStringAsFixed(2).padLeft(9)}'
        '${correctionEffect(i, v2, seeds).toStringAsFixed(2).padLeft(9)}',
      );
    }
    // ignore: avoid_print
    print(
      'aggregate snowball   v1 ${aggregateSnowball(v1, seeds).toStringAsFixed(3)}'
      '   v2 ${aggregateSnowball(v2, seeds).toStringAsFixed(3)}',
    );
  }

  test('Phase 3 exit-gate table — printed (in-sample + held-out)', () {
    printTable('in-sample', inSample);
    printTable('held-out', heldOut);
  });

  group('claim 1 — measurable improvement over v1', () {
    test('v2 point error beats v1 on the irregular-cycle datasets', () {
      for (final label in improveOn) {
        final i = profiles.indexOf(label);
        expect(
          mae(i, v2, inSample),
          lessThan(mae(i, v1, inSample)),
          reason: '$label: v2 MAE must beat v1',
        );
        expect(
          mae(i, v2, heldOut),
          lessThan(mae(i, v1, heldOut)),
          reason: '$label held-out: v2 MAE must still beat v1',
        );
      }
    });

    test('v2 holds MAE parity (≤ +3%) where v1 is already near optimal', () {
      for (final label in parityOn) {
        final i = profiles.indexOf(label);
        expect(
          mae(i, v2, inSample),
          lessThanOrEqualTo(mae(i, v1, inSample) * 1.03),
          reason: '$label: v2 MAE must not regress past +3% of v1',
        );
      }
    });

    test('v2 calibration — the wide-range profiles stop under-covering', () {
      // regular / irregular / postpartum: an honest ~90% band.
      for (final label in ['regular', 'irregular', 'postpartum']) {
        final i = profiles.indexOf(label);
        expect(
          cov(i, v2, inSample),
          greaterThanOrEqualTo(0.80),
          reason: '$label coverage floor',
        );
      }
      // pcos / perimenopause: v1's band is far too tight; v2's is materially
      // wider and clears a usable floor.
      for (final label in ['pcos', 'perimenopause']) {
        final i = profiles.indexOf(label);
        expect(
          cov(i, v2, inSample),
          greaterThan(cov(i, v1, inSample) + 0.10),
          reason: '$label: v2 coverage must clearly beat v1',
        );
        expect(
          cov(i, v2, inSample),
          greaterThanOrEqualTo(0.68),
          reason: '$label coverage floor',
        );
      }
    });
  });

  group('claim 2 — corrections demonstrably change output', () {
    test(
      'a fixed mis-log moves v2 far more than v1, and v2 actually moves',
      () {
        for (final label in [
          'irregular',
          'pcos',
          'perimenopause',
          'postpartum',
        ]) {
          final i = profiles.indexOf(label);
          final e1 = correctionEffect(i, v1, inSample);
          final e2 = correctionEffect(i, v2, inSample);
          expect(
            e1,
            lessThan(1.0),
            reason: '$label: v1 barely responds to a correction ($e1 d)',
          );
          expect(
            e2,
            greaterThan(e1 * 1.4),
            reason:
                '$label: v2 response ($e2 d) must clearly exceed v1 ($e1 d)',
          );
        }
      },
    );

    test('correcting a date does not, on average, make v2 less accurate', () {
      for (var i = 0; i < profiles.length; i++) {
        final gain = _meanGain(setsFor, i, v2, inSample);
        expect(
          gain,
          greaterThanOrEqualTo(-0.3),
          reason: '${profiles[i]}: mean correction accuracy gain $gain d',
        );
      }
    });
  });

  group('claim 3 — no snowballing', () {
    test(
      'v2 aggregate post-outlier error ratio ≤ v1 — in- and out-of-sample',
      () {
        expect(
          aggregateSnowball(v2, inSample),
          lessThanOrEqualTo(aggregateSnowball(v1, inSample)),
          reason: 'in-sample aggregate snowball: v2 must not exceed v1',
        );
        expect(
          aggregateSnowball(v2, heldOut),
          lessThanOrEqualTo(aggregateSnowball(v1, heldOut)),
          reason: 'held-out aggregate snowball: v2 must not exceed v1',
        );
      },
    );

    test('one injected outlier shifts an established forecast ≤ 3 days', () {
      // Established ~28-day history, one anomalous cycle of any magnitude at
      // position 10, scored at every later cutoff. (Condensed from
      // anti_snowball_test's 120-seed sweep.)
      var worst = 0;
      for (final outlier in [40, 45, 55, 80, 110]) {
        for (var seed = 1; seed <= 30; seed++) {
          final clean = [for (var i = 0; i < 17; i++) 28 + (seed + i) % 5 - 2];
          final dirty = [...clean]..[10] = outlier;
          for (var k = 10; k < 16; k++) {
            worst = worst > _offsetDelta(v2, clean, dirty, k)
                ? worst
                : _offsetDelta(v2, clean, dirty, k);
          }
        }
      }
      expect(
        worst,
        lessThanOrEqualTo(3),
        reason: 'worst forecast shift $worst d',
      );
    });
  });
}

/// Mean correction *accuracy gain* (days improved) for profile [i] under [p].
double _meanGain(
  List<SyntheticHistory> Function(int) setsFor,
  int i,
  Predictor p,
  List<int> seeds,
) {
  var sum = 0.0;
  var n = 0;
  for (final seed in seeds) {
    final g = runCorrectionResponseOn(
      setsFor(seed)[i],
      predictor: p,
      mislogOffsetDays: 3,
    ).meanCorrectionGainDays;
    if (g != null) {
      sum += g;
      n++;
    }
  }
  return n == 0 ? double.nan : sum / n;
}

/// |expected-date offset with the outlier − without it| at cutoff [k].
int _offsetDelta(Predictor p, List<int> clean, List<int> dirty, int k) {
  int offset(List<int> lengths) {
    var day = DateTime(2024, 1, 1);
    final starts = <DateTime>[day];
    for (var i = 0; i <= k; i++) {
      day = day.add(Duration(days: lengths[i]));
      starts.add(day);
    }
    final pred = p.predict(
      cycles: cyclesFromStarts(starts),
      today: starts.last.add(const Duration(days: 1)),
    );
    return pred == null
        ? 1 << 20
        : daysBetween(starts.last, pred.nextPeriodExpected);
  }

  return (offset(dirty) - offset(clean)).abs();
}
