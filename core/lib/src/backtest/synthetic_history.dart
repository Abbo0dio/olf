import 'dart:math' as math;

import '../cycle/cycle.dart';
import '../date_math.dart';

/// A deterministic synthetic cycle history for backtesting (p3.1).
///
/// Everything here is pure arithmetic over a **seeded** [math.Random] — the
/// same `seed` and parameters always produce a byte-identical history, so the
/// backtester ([runBacktest]) is fully reproducible in CI. No real user data,
/// no `DateTime.now()`.
///
/// [periodStarts] is the ground truth: logged period-start dates, **oldest
/// first**. [ovulationByStart] maps each completed cycle's start day to the
/// "true" ovulation day inside that cycle, for the optional ovulation-error
/// metric — callers that do not care about ovulation can ignore it.
class SyntheticHistory {
  SyntheticHistory({
    required this.label,
    required this.seed,
    required this.periodStarts,
    required this.ovulationByStart,
  }) : assert(periodStarts.length >= 2, 'need at least two period starts');

  /// Human-readable profile name (`regular`, `irregular`, `pcos`, …).
  final String label;

  /// The seed this history was generated from.
  final int seed;

  /// Logged period-start dates, oldest first, time-of-day stripped.
  final List<DateTime> periodStarts;

  /// Completed-cycle start day → true ovulation day within that cycle.
  final Map<DateTime, DateTime> ovulationByStart;

  /// Number of completed cycles (the last start opens the still-open cycle).
  int get completedCycleCount => periodStarts.length - 1;

  /// The history as [Cycle]s, **newest first** — matching `deriveCycles`'s
  /// contract, so a [Predictor] cannot tell this from real derived data.
  List<Cycle> cyclesNewestFirst() => cyclesFromStarts(periodStarts);
}

/// Build a newest-first [Cycle] list from ascending period-start dates.
///
/// The last start opens the current (open) cycle; every earlier one is a
/// completed cycle whose `nextPeriodStart` is the following start. No period
/// end dates — the next-start prediction path does not use them, and leaving
/// them out keeps the fixtures minimal.
List<Cycle> cyclesFromStarts(List<DateTime> ascendingStarts) {
  final starts = [for (final d in ascendingStarts) dateOnly(d)]..sort();
  final out = <Cycle>[
    for (var i = 0; i < starts.length; i++)
      Cycle(
        periodStart: starts[i],
        nextPeriodStart: i + 1 < starts.length ? starts[i + 1] : null,
      ),
  ];
  return out.reversed.toList();
}

/// The five profiles the harness scores against, all from one [seed].
///
/// Chosen to stress exactly the cases incumbents handle badly
/// (`requirements.md` §9(2)): steady, noisy, PCOS-like (long + very variable),
/// perimenopausal (drifting mean + growing variance + skipped cycles), and
/// postpartum (a long gap, then a gradual return to baseline).
class SyntheticHistories {
  const SyntheticHistories._();

  /// Anchor date for every generated history (arbitrary, fixed for
  /// reproducibility).
  static final DateTime defaultStart = DateTime(2024, 1, 1);

  static List<SyntheticHistory> all({int seed = 42}) => [
    regular(seed: seed),
    irregular(seed: seed),
    pcos(seed: seed),
    perimenopause(seed: seed),
    postpartum(seed: seed),
  ];

  /// ~28-day cycles, low variance — the easy case; used as the "must not
  /// regress" control.
  static SyntheticHistory regular({
    int seed = 42,
    int cycles = 24,
    DateTime? start,
  }) => _build(
    label: 'regular',
    seed: seed,
    cycles: cycles,
    start: start,
    nextLength: (rng, i, prev) => _clampLen(_gaussian(rng, 28, 1.3).round()),
  );

  /// High run-to-run variance around a normal mean, **lag-1 autocorrelated**.
  ///
  /// Real cycle lengths are not memoryless: a long cycle makes the next one more
  /// likely to be long (within-person autocorrelation is well established in the
  /// menstrual-cycle literature). The generator is a stationary AR(1) process
  /// `next = mean + phi·(prev − mean) + noise`, with **phi = 0.3 fixed** as a
  /// physiologically-motivated modelling choice — it is *not* tuned to any
  /// predictor. The noise SD is scaled by `sqrt(1 − phi²)` so the marginal
  /// (stationary) SD still matches the old i.i.d. generator's `6`.
  static SyntheticHistory irregular({
    int seed = 42,
    int cycles = 36,
    DateTime? start,
  }) => _build(
    label: 'irregular',
    seed: seed,
    cycles: cycles,
    start: start,
    nextLength: (rng, i, prev) {
      const mean = 30.0;
      const phi = 0.3;
      const marginalSd = 6.0;
      final noiseSd = marginalSd * math.sqrt(1 - phi * phi); // ≈ 5.72
      final p = (prev ?? mean).toDouble();
      return _clampLen(
        (mean + phi * (p - mean) + _gaussian(rng, 0, noiseSd)).round(),
      );
    },
  );

  /// PCOS-like: long mean, high variance, an occasional very long cycle, and
  /// **lag-1 autocorrelation** (long cycles beget long cycles).
  ///
  /// Same stationary AR(1) form as [irregular] with **phi = 0.4 fixed** (a held
  /// modelling choice, not tuned to the engine) and noise SD scaled by
  /// `sqrt(1 − phi²)` so the marginal SD matches the old generator's `9`. The
  /// occasional very-long-cycle spike is kept and, because the spiked length
  /// feeds the recursion, it decays away over the following cycles rather than
  /// vanishing instantly.
  static SyntheticHistory pcos({
    int seed = 42,
    int cycles = 36,
    DateTime? start,
  }) => _build(
    label: 'pcos',
    seed: seed,
    cycles: cycles,
    start: start,
    nextLength: (rng, i, prev) {
      const mean = 37.0;
      const phi = 0.4;
      const marginalSd = 9.0;
      final noiseSd = marginalSd * math.sqrt(1 - phi * phi); // ≈ 8.25
      final p = (prev ?? mean).toDouble();
      var len = (mean + phi * (p - mean) + _gaussian(rng, 0, noiseSd)).round();
      if (rng.nextDouble() < 0.15) len += 15 + rng.nextInt(25);
      return _clampLen(len);
    },
  );

  /// Perimenopause: the mean lengthens and the variance grows cycle over
  /// cycle, with the occasional skipped cycle (roughly doubled length).
  static SyntheticHistory perimenopause({
    int seed = 42,
    int cycles = 24,
    DateTime? start,
  }) => _build(
    label: 'perimenopause',
    seed: seed,
    cycles: cycles,
    start: start,
    nextLength: (rng, i, prev) {
      final mean = 27 + 0.6 * i;
      final sd = 2.0 + 0.35 * i;
      var len = _gaussian(rng, mean, sd).round();
      if (rng.nextDouble() < 0.12) {
        len += _gaussian(rng, mean, sd).round().clamp(15, 60);
      }
      return _clampLen(len);
    },
  );

  /// Postpartum: one long gap (lochia + first return), then cycles that start
  /// long and decay back toward a ~28-day baseline over the first several
  /// cycles.
  static SyntheticHistory postpartum({
    int seed = 42,
    int cycles = 18,
    DateTime? start,
  }) => _build(
    label: 'postpartum',
    seed: seed,
    cycles: cycles,
    start: start,
    nextLength: (rng, i, prev) {
      if (i == 0) return _clampLen(60 + rng.nextInt(61));
      final decay = math.max(0.0, 12 - i * 1.6);
      return _clampLen(_gaussian(rng, 28 + decay, 4).round());
    },
  );

  static SyntheticHistory _build({
    required String label,
    required int seed,
    required int cycles,
    required DateTime? start,
    required int Function(math.Random rng, int index, int? prevLength)
    nextLength,
    int lutealDays = 14,
    double ovulationNoiseSd = 1.5,
  }) {
    assert(cycles >= 2, 'need at least two completed cycles');
    final rng = math.Random(seed);
    final anchor = dateOnly(start ?? defaultStart);

    final starts = <DateTime>[anchor];
    int? prevLength;
    for (var i = 0; i < cycles; i++) {
      final len = nextLength(rng, i, prevLength);
      starts.add(addDays(starts.last, len));
      prevLength = len;
    }

    // Ovulation truth is drawn afterwards, still from the same seeded stream,
    // so the whole history stays a pure function of (seed, params).
    final ovulation = <DateTime, DateTime>{};
    for (var i = 0; i < starts.length - 1; i++) {
      final noise = _gaussian(rng, 0, ovulationNoiseSd).round();
      ovulation[starts[i]] = addDays(starts[i + 1], -lutealDays + noise);
    }

    return SyntheticHistory(
      label: label,
      seed: seed,
      periodStarts: starts,
      ovulationByStart: ovulation,
    );
  }
}

/// Box–Muller normal sample. `math.Random.nextDouble()` is a deterministic
/// PRNG when seeded, so this is reproducible.
double _gaussian(math.Random rng, double mean, double sd) {
  final u1 = 1.0 - rng.nextDouble();
  final u2 = 1.0 - rng.nextDouble();
  final mag = sd * math.sqrt(-2.0 * math.log(u1));
  return mag * math.cos(2 * math.pi * u2) + mean;
}

/// Keep every generated cycle length physically plausible.
int _clampLen(int days) => days.clamp(15, 120);
