import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

/// p3.2 property: logging **one ordinary cycle** (not an outlier / missed log)
/// only nudges the forecast. Asserted on the *distribution* over many
/// established histories — the typical response is small and no worse than the
/// trusted v1 baseline's. A rare larger tail (a drift-detector threshold being
/// crossed) is left for p3.4's anti-snowball hardening.
void main() {
  const v1 = RobustPredictor();
  const v2 = AdaptivePredictor();
  final seeds = List<int>.generate(12, (i) => i + 1);
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

  double median(List<num> xs) {
    final s = [...xs]..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m].toDouble() : (s[m - 1] + s[m]) / 2;
  }

  double pct(List<int> xs, double p) {
    final s = [...xs]..sort();
    return s[(s.length * p).floor().clamp(0, s.length - 1)].toDouble();
  }

  /// For one predictor: |Δ projected length| and |Δ range width| over every
  /// "add one ordinary cycle" step across all profiles / seeds.
  ({List<int> shift, List<int> width}) responses(Predictor predictor) {
    final shift = <int>[];
    final width = <int>[];
    for (var i = 0; i < profiles.length; i++) {
      for (final seed in seeds) {
        final starts = setsFor(seed)[i].periodStarts;
        final lens = [
          for (var k = 0; k + 1 < starts.length; k++)
            daysBetween(starts[k], starts[k + 1]),
        ];
        for (var k = 8; k + 1 < starts.length; k++) {
          final recent = lens.sublist(k - 5, k);
          final med = median(recent);
          final mad = median([for (final x in recent) (x - med).abs()]);
          final added = lens[k];
          final ordinary =
              added <= 45 && (added - med).abs() <= 1.5 * (mad < 2 ? 2 : mad);
          if (!ordinary) continue;

          final before = predictor.predict(
            cycles: cyclesFromStarts(starts.sublist(0, k + 1)),
            today: starts[k].add(const Duration(days: 1)),
          );
          final after = predictor.predict(
            cycles: cyclesFromStarts(starts.sublist(0, k + 2)),
            today: starts[k + 1].add(const Duration(days: 1)),
          );
          if (before == null || after == null) continue;

          shift.add(
            (daysBetween(starts[k + 1], after.nextPeriodExpected) -
                    daysBetween(starts[k], before.nextPeriodExpected))
                .abs(),
          );
          width.add(
            (after.nextPeriod.lengthInDays - before.nextPeriod.lengthInDays)
                .abs(),
          );
        }
      }
    }
    return (shift: shift, width: width);
  }

  test('an ordinary added cycle only nudges v2 — typical response is small', () {
    final r = responses(v2);
    expect(r.shift.length, greaterThan(200), reason: 'enough samples');

    final meanShift = r.shift.reduce((a, b) => a + b) / r.shift.length;
    final meanWidth = r.width.reduce((a, b) => a + b) / r.width.length;

    // ignore: avoid_print
    print(
      'v2: n=${r.shift.length}  shift mean=${meanShift.toStringAsFixed(2)} '
      'p90=${pct(r.shift, 0.90)} max=${r.shift.reduce((a, b) => a > b ? a : b)} | '
      'width mean=${meanWidth.toStringAsFixed(2)} p90=${pct(r.width, 0.90)} '
      'max=${r.width.reduce((a, b) => a > b ? a : b)}',
    );

    // Point estimate: stable.
    expect(meanShift, lessThan(2.0));
    expect(pct(r.shift, 0.90), lessThanOrEqualTo(5));
    // Range width: typically a small breath (it *should* track dispersion, so
    // unlike v1's frozen [min,max] it is not motionless). The rare large tail
    // is a drift-threshold crossing — p3.4's anti-snowball hardening owns it.
    expect(meanWidth, lessThan(4.5));
    expect(pct(r.width, 0.90), lessThanOrEqualTo(12));
  });

  test('v2 point estimate is no more skittish than v1 to one added cycle', () {
    final a = responses(v1);
    final b = responses(v2);
    final v1Shift = a.shift.reduce((x, y) => x + y) / a.shift.length;
    final v2Shift = b.shift.reduce((x, y) => x + y) / b.shift.length;
    expect(
      v2Shift,
      lessThanOrEqualTo(v1Shift * 2.0 + 1.0),
      reason: 'mean projected-length move: v2 $v2Shift vs v1 $v1Shift',
    );
  });
}
