import 'dart:math' as math;

import '../cycle/cycle.dart';
import '../date_math.dart';
import 'date_range.dart';
import 'predictor.dart';
import 'robust_predictor.dart'
    show
        fertileDaysAfterOvulation,
        fertileDaysBeforeOvulation,
        lutealPhaseDays,
        minPredictionMarginDays;

/// Adaptive [Predictor] (p3.2) — explainable, plain-Dart statistics only.
///
/// It is deliberately **not** a machine-learning model: every number below is
/// arithmetic you can follow by hand, which matters for a health prediction the
/// user is asked to trust and correct (`requirements.md` §4).
///
/// Pipeline, from the completed-cycle length series (newest cycle first,
/// pregnancy gaps removed; a probable missed log is down-weighted, not dropped):
///
/// 0. **Plausibility down-weight.** Each cycle carries a weight in `[0, 1]` that
///    ramps linearly down over the ~10 days past the 45-day mark (or the
///    person's own median, capped). A likely missed log lands at weight 0 — but
///    the ramp, not a step, means a one- or two-day edit near the mark can't
///    lurch the forecast, and cycles past the ramp are also dropped from the
///    trend / dispersion estimators outright.
/// 1. **Recency weighting.** Cycle `i` back from the newest gets weight
///    `decay^i` (times its plausibility). The engine **widens its memory when
///    cycles are steady and shortens it when they are changing**: [_decayStable]
///    with no trend, ramping smoothly toward [_decayTrending] as a level shift
///    strengthens. `nEff` — the sum of the weights — is the *effective* sample
///    size.
/// 2. **Robust centre.** A recency-weighted quantile near the **median** of the
///    recent lengths — unmoved by one freak long cycle (PCOS), unlike a mean —
///    nudged toward the shorter side on a right-skewed history.
/// 3. **Drift.** A robust monotone level-shift term over the last [_driftWindow]
///    lengths (the thirds' medians must move monotonically and clear the
///    series' own MAD-scaled noise floor). If it fires it is added once, capped
///    at [_maxDriftPerCycle]. This tracks a lengthening perimenopausal trend or
///    a shortening postpartum return instead of averaging across it.
/// 3b. **Lag-1 mean-reversion.** When there is *no* detected trend, the recent
///    lag-1 autocorrelation (`phiHat`, clamped to `[0, 0.55]`) pulls the
///    forecast a fraction of the last cycle's deviation from the level — a long
///    cycle nudges the next estimate up. Capped at [_maxArShiftDays]; trending
///    histories skip it because [_drift] already carries the systematic part;
///    **gated off when the last cycle is an outlier** (`|last − median| >
///    2·MAD`), so a PCOS-type spike is not chased.
/// 4. **Bayesian shrinkage (thin history only).** The centre is blended with a
///    weak population prior (mean [_priorMean], pseudo-count [_priorWeight]).
///    With `nEff` of 8+ the prior is negligible; with one or two cycles it
///    keeps the estimate sane. The interval is widened by
///    `sqrt(1 + 2/(priorWeight + nEff))` for the same reason.
/// 5. **Interval — empirical, calibrated.** Half-width = a recency-weighted
///    quantile (near [nominalCoverage], lifted for finite samples and fat
///    tails) of the absolute deviations of past lengths from the centre,
///    floored at [minPredictionMarginDays] and widened by the thin-history
///    factor. By construction ~[nominalCoverage] of past cycles fell inside a
///    band that wide, so if the near future resembles the near past the stated
///    coverage ≈ the observed coverage — no normality assumption, which matters
///    for the fat-tailed PCOS case.
/// 6. **Anchor.** Everything hangs off the last logged period start
///    (`cycles.first.periodStart`) — exactly as v1, so a late period never
///    rolls the expected date forward on its own.
///
/// `today` is injected; there is no `DateTime.now()` here, so a backtest over a
/// fixed history is fully reproducible.
class AdaptivePredictor implements Predictor {
  const AdaptivePredictor();

  /// The nominal next-period interval this engine aims for (~90%). The
  /// calibration test checks the backtested coverage clears a **one-sided 0.80
  /// floor** on every synthetic profile — with ~23–35 scored points per set a
  /// two-sided ±5-pt band around 0.90 is finer than the sampling noise, so the
  /// bar is "the ~90% range must not under-cover badly", not "hit 0.90 exactly".
  static const double nominalCoverage = 0.90;

  /// A flat multiplier on the empirical half-width. An in-sample deviation
  /// quantile systematically under-covers out of sample (more so on the short,
  /// fat-tailed non-regular histories); this lifts the ~90% band back onto its
  /// ≥ 0.80 coverage floor across every profile.
  static const double _widthSafety = 1.06;

  /// Per-cycle geometric decay for recency weighting. The engine **widens its
  /// memory when your cycles are steady and shortens it when they are
  /// changing**: a stationary history uses [_decayStable] (long memory → a
  /// low-variance centre), a history with a detected trend uses
  /// [_decayTrending] (short memory → the centre tracks the new regime).
  static const double _decayStable = 0.96;
  static const double _decayTrending = 0.82;

  /// Weak population prior for the Bayesian blend — only bites with very little
  /// history.
  static const double _priorMean = 29;
  static const double _priorWeight = 0.5;

  /// Drift (trend) handling. Split the recent history into thirds; a trend
  /// counts only when the thirds' medians move **monotonically** and the total
  /// move clears the series' own noise floor (a multiple of its MAD). The
  /// per-cycle slope is then applied once, capped.
  static const int _driftWindow = 15;
  static const int _driftMinCycles = 9;
  static const double _driftMadFactor = 1.6;
  static const double _driftMinShiftDays = 4.0;
  static const double _maxDriftPerCycle = 2.5;

  /// Memory ([decay]) ramps from long to short as the detected per-cycle drift
  /// grows across this band: at or below [_driftDeadbandDays] the history still
  /// counts as stationary (long memory); at or above [_driftSaturateDays] it is
  /// a firm trend (short memory, tracks the new regime — e.g. a postpartum
  /// return). The ramp, not a step, keeps a noisy edit from flipping memory.
  static const double _driftDeadbandDays = 0.25;
  static const double _driftSaturateDays = 1.0;

  /// Lag-1 mean-reversion. `phiHat` is estimated over at most this many recent
  /// cycles and clamped to `[0, _arPhiCap]`; the resulting forecast shift is
  /// capped at `_maxArShiftDays`.
  static const int _arWindow = 12;
  static const int _arMinCycles = 6;
  static const double _arPhiCap = 0.55;
  static const double _maxArShiftDays = 6.0;

  /// The AR term is gated off when the last cycle sits more than this many
  /// robust MADs from the recent median (an unpredictable shock).
  static const double _arOutlierMadFactor = 2.0;

  /// Graded "is this a real cycle or a missed log?" down-weight. A cycle up to
  /// [_plausibleCycleDays] (or the person's own median, whichever is larger)
  /// counts fully; over the next [_plausibilityRampDays] the weight ramps
  /// **linearly to zero**. The ramp (not a step) is what stops a 1–2 day edit
  /// near the 45-day mark from lurching the forecast; past the ramp a cycle is
  /// genuinely not menstrual (a postpartum lochia stretch, a long missed gap)
  /// and is dropped from the trend / dispersion estimators entirely. Cycles
  /// still inside the ramp are also capped at median + [_winsorMarginDays]
  /// before the trend / lag-1 estimators.
  static const int _plausibleCycleDays = 45;
  static const double _plausibilityRampDays = 10;
  static const double _winsorMarginDays = 12;

  /// If the plausibility-weighted history carries less than this much effective
  /// evidence, there is no usable cycle to speak from — return `null`.
  static const double _minEffectiveCycles = 0.4;

  /// The predicted range is never narrower than ±this — a date is never claimed
  /// to the day (shared with v1).
  static const int _minMargin = minPredictionMarginDays;

  @override
  CyclePrediction? predict({
    required List<Cycle> cycles,
    required DateTime today,
  }) {
    if (cycles.isEmpty) return null;

    // p1.11: the open cycle covers a recorded pregnancy loss / birth — no
    // post-event anchor yet. Say nothing rather than project across it.
    if (cycles.first.isPregnancyGap) return null;

    // Completed cycle lengths, newest first, up to the most recent pregnancy
    // gap. The open (current) cycle is dropped. Over-long cycles — a probable
    // missed log — are **kept but smoothly down-weighted** ([_plausibility]),
    // never hard-excluded, so a one- or two-day edit near the 45-day mark
    // cannot make a whole cycle blink in or out of the estimate.
    final lengths = <int>[
      for (final c in cycles.takeWhile((c) => !c.isPregnancyGap))
        if (!c.isCurrent) c.lengthInDays!,
    ];
    if (lengths.isEmpty) return null;

    final anchor = cycles.first.periodStart;
    final t = dateOnly(today);

    final rawMedian = _median(lengths);
    final plausibility = [
      for (final len in lengths) _plausibility(len, rawMedian),
    ];

    // A winsorised copy for the trend and lag-1 estimators — they cannot
    // consume the weight vector, so an over-long-but-still-plausible cycle is
    // capped here, and a fully implausible one (weight 0) is left out.
    final cap = (rawMedian + _winsorMarginDays).round();
    final winsor = [
      for (var i = 0; i < lengths.length; i++)
        if (plausibility[i] > 0) math.min(lengths[i], cap),
    ];

    // --- 1. drift (robust monotone level-shift detector) ----------------
    // Only a monotone shift across the recent thirds that clears the series'
    // own noise floor counts as a trend — a noisy stationary history
    // (irregular / PCOS) must not pick up a spurious slope. chronological.
    final chron = winsor.reversed.toList();
    final appliedDrift = _drift(chron);

    // --- 2. recency weights (index 0 = newest) --------------------------
    // Memory shortens **smoothly** as the detected drift grows: no trend → long
    // memory ([_decayStable]); a full-strength trend → short memory
    // ([_decayTrending]); in between, in between — no binary switch for a noisy
    // edit to flip. Each weight also carries its cycle's [_plausibility].
    final driftFrac =
        ((appliedDrift.abs() - _driftDeadbandDays) /
                (_driftSaturateDays - _driftDeadbandDays))
            .clamp(0.0, 1.0);
    final decay = _decayStable - (_decayStable - _decayTrending) * driftFrac;
    final trending = driftFrac > 0;
    final weights = [
      for (var i = 0; i < lengths.length; i++)
        math.pow(decay, i) * plausibility[i] + 0.0,
    ];
    final nEff = weights.fold<double>(0, (a, b) => a + b);
    if (nEff < _minEffectiveCycles) return null;

    // --- 3. robust weighted centre + drift step ------------------------
    // On a right-skewed history — occasional very long PCOS-type cycles — the
    // *typical* (non-outlier) cycle sits a little below the middle value, so
    // the centre quantile is nudged down in proportion to the skew. Symmetric
    // histories keep the plain weighted median.
    final wMedian = _weightedMedian(lengths, weights);
    final wMean = _weightedMean(lengths, weights);
    final skew = wMean - wMedian;
    final centreQ = (0.5 - 0.03 * skew.clamp(0.0, 4.0)).clamp(0.38, 0.5);
    final centre =
        _weightedQuantile([
          for (var i = 0; i < lengths.length; i++)
            (v: lengths[i], w: weights[i]),
        ], centreQ) +
        appliedDrift;

    // --- 3b. lag-1 mean-reversion (AR(1)) correction ------------------
    // Cycle lengths carry short memory: a long cycle makes the next one lean
    // long. When there is no detected trend, estimate the lag-1 autocorrelation
    // of the recent lengths and pull the forecast a fraction of the last
    // cycle's deviation from the level. `phiHat` is clamped to [0, 0.55] (cycle
    // lengths do not anti-correlate; the cap guards a noisy estimate) and the
    // shift itself is capped. Trending histories skip this — the drift term
    // already carries the systematic part.
    final arShift = _arCorrection(winsor, centre, trending);
    final forecastCentre = centre + arShift;

    // --- 4. Bayesian shrinkage (thin history) -------------------------
    final posteriorCentre =
        (_priorWeight * _priorMean + nEff * forecastCentre) /
        (_priorWeight + nEff);
    final thinInflation = math.sqrt(1 + 2.0 / (_priorWeight + nEff));

    // --- 5. empirical calibrated interval ---------------------------
    // Band = recency-weighted quantile of past |length − centre|, at a target
    // quantile lifted above the nominal coverage by (a) a finite-sample term
    // (more with little data) and (b) a tail-heaviness term, because an
    // in-sample quantile under-covers out of sample — worst for fat-tailed
    // PCOS histories.
    final absDevs = [
      for (var i = 0; i < lengths.length; i++)
        if (plausibility[i] > 0)
          (v: (lengths[i] - centre).abs(), w: weights[i]),
    ];
    final tailRatio =
        _weightedQuantile(absDevs, 0.92) /
        math.max(1.0, _weightedQuantile(absDevs, 0.6));
    final tailBump = 1 + 0.18 * (tailRatio - 2.0).clamp(0.0, 4.0);
    final q = (nominalCoverage * (1 + 0.30 / nEff)).clamp(0.0, 0.985);
    final halfWidth = math.max(
      _minMargin.toDouble(),
      _weightedQuantile(absDevs, q) * thinInflation * tailBump * _widthSafety,
    );

    // --- 6. anchor + assemble ----------------------------------------------
    final expectedDays = posteriorCentre.round();
    final margin = math.max(_minMargin, halfWidth.round());

    final expected = addDays(anchor, expectedDays);
    final earliest = addDays(anchor, expectedDays - margin);
    final latest = addDays(anchor, expectedDays + margin);

    final ovulation = addDays(expected, -lutealPhaseDays);
    final fertileWindow = DateRange(
      addDays(ovulation, -fertileDaysBeforeOvulation),
      addDays(ovulation, fertileDaysAfterOvulation),
    );

    final PredictionStatus status;
    final int? daysPastExpected;
    if (t.isBefore(earliest)) {
      status = PredictionStatus.upcoming;
      daysPastExpected = null;
    } else if (!t.isAfter(latest)) {
      status = PredictionStatus.dueNow;
      daysPastExpected = null;
    } else {
      status = PredictionStatus.overdue;
      daysPastExpected = daysBetween(expected, t);
    }

    return CyclePrediction(
      nextPeriod: DateRange(earliest, latest),
      nextPeriodExpected: expected,
      fertileWindow: fertileWindow,
      confidence: _confidence(
        nEff: nEff,
        halfWidth: halfWidth,
        regimeChanged: appliedDrift.abs() >= 1.0,
        usableCycles: lengths.length,
      ),
      basedOnCycles: lengths.length,
      status: status,
      daysPastExpected: daysPastExpected,
    );
  }

  /// Graded plausibility weight in `[0, 1]` for a completed cycle of [len] days,
  /// given the person's robust [level]. Continuous in [len] through the ramp;
  /// exactly zero past it (a genuine non-menstrual stretch).
  double _plausibility(int len, double level) {
    // The person's own median can lift the "counts fully" mark above 45 — but
    // only so far, so a lone freak-long cycle (its own median) can't declare
    // itself plausible.
    final full = math.max(
      _plausibleCycleDays.toDouble(),
      math.min(level, _plausibleCycleDays + _winsorMarginDays),
    );
    final zero = full + _plausibilityRampDays;
    if (len <= full) return 1;
    if (len >= zero) return 0;
    return 1 - (len - full) / (zero - full);
  }

  /// Per-cycle drift, or 0 when the recent history shows no clear monotone
  /// trend. [chron] is oldest → newest.
  double _drift(List<int> chron) {
    if (chron.length < _driftMinCycles) return 0;
    final w = chron.sublist(math.max(0, chron.length - _driftWindow));
    final third = w.length ~/ 3;
    if (third < 2) return 0;
    final lo = _median(w.sublist(0, third));
    final mid = _median(w.sublist(third, w.length - third));
    final hi = _median(w.sublist(w.length - third));

    final rising = hi > mid && mid > lo;
    final falling = hi < mid && mid < lo;
    if (!rising && !falling) return 0;

    final shift = hi - lo;
    final mad = _median([for (final x in w) (x - _median(w)).abs().round()]);
    final floor = math.max(_driftMinShiftDays, _driftMadFactor * mad);
    if (shift.abs() < floor) return 0;
    // both legs of the trend must be real, not one big jump plus noise.
    if ((mid - lo).abs() < 0.25 * floor || (hi - mid).abs() < 0.25 * floor) {
      return 0;
    }

    // centres of the outer thirds are ~ (w.length - third) cycles apart.
    final perCycle = shift / (w.length - third);
    return perCycle.clamp(-_maxDriftPerCycle, _maxDriftPerCycle);
  }

  /// A fraction of the most recent cycle's deviation from [centre], sized by the
  /// recent lag-1 autocorrelation. 0 when trending, when the history is too
  /// short, when the estimate is non-positive, or — the **outlier gate** — when
  /// the most recent cycle is itself a shock far from the recent median: you
  /// cannot mean-revert from something you could not have forecast, and chasing
  /// a spike doubles the error when it snaps back. [newestFirst] is newest-first.
  double _arCorrection(List<int> newestFirst, double centre, bool trending) {
    if (trending || newestFirst.length < _arMinCycles) return 0;
    final w = newestFirst
        .take(math.min(_arWindow, newestFirst.length))
        .toList();

    final wMedian = _median(w);
    final mad = math.max(
      1.0,
      _median([for (final x in w) (x - wMedian).abs().round()]),
    );
    if ((newestFirst.first - wMedian).abs() > _arOutlierMadFactor * mad) {
      return 0;
    }

    final mean = w.reduce((a, b) => a + b) / w.length;
    var cov = 0.0;
    var varr = 0.0;
    for (var i = 0; i + 1 < w.length; i++) {
      cov += (w[i] - mean) * (w[i + 1] - mean);
      varr += (w[i + 1] - mean) * (w[i + 1] - mean);
    }
    if (varr <= 0) return 0;
    final phiHat = (cov / varr).clamp(0.0, _arPhiCap);
    if (phiHat == 0) return 0;
    final lastDev = newestFirst.first - centre;
    return (phiHat * lastDev).clamp(-_maxArShiftDays, _maxArShiftDays);
  }

  PredictionConfidence _confidence({
    required double nEff,
    required double halfWidth,
    required bool regimeChanged,
    required int usableCycles,
  }) {
    if (usableCycles < 2 || nEff < 1.5) return PredictionConfidence.low;
    if (regimeChanged) return PredictionConfidence.low;
    if (nEff >= 3 && halfWidth <= 3) return PredictionConfidence.high;
    if (nEff >= 2 && halfWidth <= 7) return PredictionConfidence.medium;
    return PredictionConfidence.low;
  }
}

// --- plain-Dart statistics helpers ---------------------------------------

typedef _WV = ({num v, double w});

/// Weighted median: the value where cumulative weight first reaches half the
/// total. `values` and `weights` are parallel and non-empty.
double _weightedMedian(List<int> values, List<double> weights) =>
    _weightedQuantile([
      for (var i = 0; i < values.length; i++) (v: values[i], w: weights[i]),
    ], 0.5);

/// Weighted arithmetic mean of `values`.
double _weightedMean(List<int> values, List<double> weights) {
  var sw = 0.0;
  var swx = 0.0;
  for (var i = 0; i < values.length; i++) {
    sw += weights[i];
    swx += weights[i] * values[i];
  }
  return sw == 0 ? 0 : swx / sw;
}

/// The [level] (0..1) weighted quantile of `pairs` by value. Walks the sorted
/// values accumulating weight; returns the first value whose cumulative weight
/// reaches `level` of the total. Empty → 0.
double _weightedQuantile(List<_WV> pairs, double level) {
  if (pairs.isEmpty) return 0;
  final sorted = [...pairs]..sort((a, b) => a.v.compareTo(b.v));
  final total = sorted.fold<double>(0, (a, p) => a + p.w);
  if (total == 0) return sorted.last.v.toDouble();
  var cum = 0.0;
  for (final p in sorted) {
    cum += p.w;
    if (cum >= level * total) return p.v.toDouble();
  }
  return sorted.last.v.toDouble();
}

/// Plain (unweighted) median of a non-empty int list.
double _median(List<int> xs) {
  final s = [...xs]..sort();
  final mid = s.length ~/ 2;
  return s.length.isOdd ? s[mid].toDouble() : (s[mid - 1] + s[mid]) / 2;
}
