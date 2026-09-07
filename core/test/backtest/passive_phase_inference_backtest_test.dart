import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

/// p8.5 — score the passive inference **directly** (not through `runBacktest`,
/// which only asks the predictor at `anchor + 1`).
///
/// For every completed cycle of every seeded profile, replay `inferPassivePhase`
/// at `today = trueOvulation + d` for `d` in a mid-luteal sweep, treating that
/// cycle as the open one. Records:
///  * ovulation-day absolute error once a shift is confirmed;
///  * whether detection ever fires;
///  * confidence monotonicity as `d` grows.
void main() {
  /// Treat [cycleStart] .. [nextStart] as the current open cycle.
  List<Cycle> asOpen(DateTime cycleStart) => [Cycle(periodStart: cycleStart)];

  ({int detected, int total, List<int> ovErrors, bool confMonotone})
  scoreProfile(SyntheticHistory h, {double missRate = 0.12}) {
    final temps = syntheticPassiveTemperature(h, missRate: missRate);
    final byCycle = <DateTime, List<BbtEntry>>{};
    for (final e in temps) {
      // bucket each reading into the cycle it belongs to
      for (var i = 0; i < h.periodStarts.length - 1; i++) {
        final s = dateOnly(h.periodStarts[i]);
        final n = dateOnly(h.periodStarts[i + 1]);
        final d = dateOnly(e.date);
        if (!d.isBefore(s) && d.isBefore(n)) {
          (byCycle[s] ??= []).add(e);
          break;
        }
      }
    }

    var detected = 0;
    var total = 0;
    final ovErrors = <int>[];
    var confMonotone = true;

    for (var i = 0; i < h.periodStarts.length - 1; i++) {
      final cycleStart = dateOnly(h.periodStarts[i]);
      final nextStart = dateOnly(h.periodStarts[i + 1]);
      final truth = h.ovulationByStart[h.periodStarts[i]];
      if (truth == null) continue;
      final trueOv = dateOnly(truth);
      final rows = byCycle[cycleStart] ?? const <BbtEntry>[];
      total++;

      var everDetected = false;
      var lastConf = -1;
      for (var d = 2; d <= 12; d++) {
        final today = addDays(trueOv, d);
        if (!today.isBefore(nextStart)) break;
        final est = inferPassivePhase(
          temperatures: rows,
          cycles: asOpen(cycleStart),
          prediction: null,
          today: today,
        );
        if (est == null) continue;
        everDetected = true;
        ovErrors.add(daysBetween(trueOv, est.estimatedOvulation).abs());
        if (est.confidence.index < lastConf) confMonotone = false;
        lastConf = est.confidence.index;
      }
      if (everDetected) detected++;
    }

    return (
      detected: detected,
      total: total,
      ovErrors: ovErrors,
      confMonotone: confMonotone,
    );
  }

  double median(List<int> xs) {
    if (xs.isEmpty) return double.nan;
    final s = [...xs]..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m].toDouble() : (s[m - 1] + s[m]) / 2;
  }

  test('regular: ovulation is placed within ~1–2 days once confirmed', () {
    final r = scoreProfile(SyntheticHistories.regular());
    expect(
      r.detected,
      greaterThan(r.total * 0.6),
      reason: 'shift should be confirmable on most regular cycles',
    );
    expect(median(r.ovErrors), lessThanOrEqualTo(2.0));
    expect(r.confMonotone, isTrue);
  });

  test('detection fires on every profile that has a real luteal shift', () {
    for (final h in SyntheticHistories.all()) {
      final r = scoreProfile(h);
      expect(
        r.detected,
        greaterThan(0),
        reason: '${h.label}: never detected a shift',
      );
      expect(r.confMonotone, isTrue, reason: '${h.label}: confidence dipped');
      if (r.ovErrors.isNotEmpty) {
        // Even on the noisy profiles the estimate should be in the right week.
        expect(
          median(r.ovErrors),
          lessThanOrEqualTo(3.0),
          reason: '${h.label}: ovulation estimate too far off',
        );
      }
    }
  });

  test('a heavily gap-riddled series stays honestly silent', () {
    // 70% of nights missing → a 6+3 run almost never forms.
    final r = scoreProfile(SyntheticHistories.regular(), missRate: 0.7);
    expect(
      r.detected,
      lessThan(r.total),
      reason: 'a mostly-empty series must not always claim a shift',
    );
  });
}
