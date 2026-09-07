# Passive cycle-phase inference (Phase 8 / p8.5)

A pure-`core` read of the **passive temperature history** that says one thing
about the current cycle: whether the post-ovulatory temperature rise has already
happened. It feeds the Phase 3 predictor as one more observation and shows up as
a plain-language caption under the cycle wheel (p1.12). It is an **estimate**,
always correctable by logging, and it makes **no diagnosis** (§6, §9(12)).

Entry point: `inferPassivePhase(...)` in
`core/lib/src/wearable/passive_phase_inference.dart`. Decorator that wires it
into prediction: `PassiveInformedPredictor` in the same directory.

## Inputs

| Input | Source | Required? |
|---|---|---|
| `temperatures` | every `bbt_entries` row — manual basal entries, `basalBodyTemperature` health-platform imports, and p8.1a Apple Watch `sleepingWrist` rows | **yes** — temperature is the only mandatory signal |
| `cycles` | `deriveCycles(...)` output, newest-first; `cycles.first` is the open cycle being estimated | yes |
| `prediction` | the current `CyclePrediction` (from `AdaptivePredictor`) | accepted; not consumed by v1 (kept so a later revision can cross-check the inferred ovulation against the forecast window without an API change) |
| `today` | injected clock — no `DateTime.now()` in `core` | yes |
| `hrv` / `sleep` | `PassiveHrvSample` / `PassiveSleepSample` lists | **accepted, not consumed in p8.5.** The signature is HRV/sleep-ready so p8.6 corroboration is purely additive; ingesting either from the OS health store (a new `HealthSampleType` + `HealthUnit(ms)` + bridge wiring on both platforms) is a separate follow-up. |

With **zero** manual logging a device-only user still gets a result from the
`sleepingWrist` track alone. With **no** passive temperature data at all the
function returns `null` and the predictor is a byte-for-byte pass-through —
exactly today's behaviour.

## Pipeline

Deterministic rule/threshold stages — no fitted model, no ML dependency.

### Stage 0 — anchor on the open cycle

Return `null` (honest "not enough signal") when:

- `cycles` is empty, or
- `cycles.first` is not the current cycle (`!isCurrent`), or is a pregnancy gap
  (`isPregnancyGap`) or a likely missed-entry gap (`isLikelyGap`), or
- the cycle start is after `today`.

### Stage 1 — build one track (never a blend)

Filter `temperatures` to `[cycleStart, today]`, then split by `measurementKind`:

- **basal track** — `measurementKind == basal` rows (any `source`), used as-is;
- **sleeping-wrist track** — `sleepingWrist` rows, re-typed to `basal` so the
  detector consumes them directly.

Pick **one** track: the basal track if it has ≥ **9** readings
(`_minTrackReadings` — the "3 over 6" rule's 6 baseline + 3 elevated), otherwise
the wrist track if it has ≥ 9, otherwise return `null`.

The two tracks are **never mixed inside one baseline/elevated window.** Wrist
temperature runs cooler and noisier than oral basal; a shared coverline computed
across both scales would be meaningless. Preferring the basal track when it
qualifies keeps the more accurate signal in charge; the wrist track is the
zero-effort fallback.

### Stage 2 — detect the shift (p7.3 primitive, reused)

Call `thermalShift(track, cycleStart:, today:)` — the same "3 over 6" detector
TTC mode uses (`core/lib/src/bbt/thermal_shift.dart`). There is deliberately
**no second shift detector**. `null` from it → `null` from us.

`thermalShift` gives `shiftDate`, `estimatedOvulation` (= `shiftDate − 1 day`),
and `riseCelsius` (how far the shift-day reading sat above the baseline
coverline).

### Stage 3 — read + confidence

- `read` is always `PassivePhaseRead.ovulationLikelyPassed` — the enum has no
  other value. A thermal shift can confirm a rise happened; it can **never**
  establish that ovulation did *not* occur, and it is not a fertility or
  pregnancy verdict.
- `estimatedOvulation` = `shift.estimatedOvulation` (coarse — temperature places
  ovulation only to within a day or two).
- `postShiftReadingCount` = readings on or after `shiftDate`.
- `density` = `readings / (daysBetween(cycleStart, lastReading) + 1)` — measured
  up to the **last reading**, not up to `today`, so an advancing clock with no
  new data never lowers confidence.
- `riseMargin` = `riseCelsius − thermalShiftThresholdCelsius` (0.2 °C).

**Confidence** (`_confidence`) is a coarse band from a 0–4 score, monotonic in
every input — each check can only add a point:

| Check | +1 when |
|---|---|
| sustained rise | `postShiftReadingCount >= 3` |
| well-sustained rise | `postShiftReadingCount >= 6` |
| clear of the noise floor | `riseMargin >= 0.1` °C |
| dense logging | `density >= 0.6` |

`score >= 4` → `high`, `>= 2` → `medium`, else `low`. A low-confidence result is
still returned (it is a real shift); `null` is reserved for *no* detectable
shift or *too thin* a track.

## Integration with the predictor

`PassiveInformedPredictor implements Predictor` — a decorator, injected with the
temperature series via its constructor. The `Predictor` interface does **not**
change.

`predict(...)`:

1. `base = inner.predict(...)`. If `null`, return `null`.
2. `estimate = inferPassivePhase(..., prediction: base)`. If `null` or not
   `ovulationLikelyPassed`, return `base` unchanged.
3. Clamp the inferred ovulation to `[cycleStart, today]`; outside that, return
   `base`.
4. Return `base.copyWith(fertileWindow: <window re-anchored on the inferred
   ovulation>)` — `[ovulation − fertileDaysBeforeOvulation, ovulation +
   fertileDaysAfterOvulation]`.

**Only `fertileWindow` is touched.** `nextPeriod`, `nextPeriodExpected`,
`confidence`, `basedOnCycles`, `status`, `daysPastExpected` are passed through
verbatim. `PredictionDelta.between` (the p3.3 correction notice) does not compare
`fertileWindow`, so refining it raises no spurious "your update was applied"
banner. `currentCyclePhase(...)` derives the wheel's ovulatory segment from
`prediction.fertileWindow`, so the refined window moves that segment on its own.

A user's logged correction (a period start, a temperature) re-derives `cycles`
and the forecast from scratch on the next read — the correction always wins.

### App wiring

Only `predictionProvider` changes — it composes the decorator over
`predictorProvider` (still bare `AdaptivePredictor`, which the p3.3 correction
loop and p3.5 accuracy screen read directly). `passivePhaseEstimateProvider`
exposes the raw estimate to the caption; it reads the **bare** predictor to
avoid a provider cycle.

## Measured against the Phase 3 backtester

`syntheticPassiveTemperature(SyntheticHistory)` gives each seeded profile
(regular, irregular, PCOS, perimenopause, postpartum) a passive-signal track:
per cycle, a low-phase mean plus Gaussian noise, a `+shiftC` step from
`trueOvulation + 1`, each day independently dropped at `missRate`.

Two test tracks:

- `passive_inference_backtest_test.dart` — `runBacktestOn` with
  `PassiveInformedPredictor(inner: AdaptivePredictor(), …)` vs the bare
  `AdaptivePredictor` baseline, all five profiles: combined `meanAbsErrorDays`,
  `coverage`, and `ovulationMeanAbsErrorDays` must not regress. They are equal by
  construction — the backtest calls `predict` at `asOf = anchor + 1`, when the
  open cycle has no post-ovulatory readings yet, so the decorator is a pure
  pass-through at that timing. **Headline: no change to backtested next-period
  MAE or calibration** — the passive layer only refines the *current* cycle's
  fertile window, which the anchor+1 backtest never scores.
- `passive_phase_inference_backtest_test.dart` — scores `inferPassivePhase`
  directly at mid-luteal `today` points on each completed synthetic cycle:
  detection rate, ovulation-day error, confidence monotonicity. Regular profile:
  detection > 60 % of cycles, median ovulation error ≤ 2 days; every profile
  detects at least some cycles with median error ≤ 3 days; a heavily-gapped
  track (missRate 0.7) detects strictly fewer.

## What this deliberately does **not** say

- Never "you did not ovulate" / "anovulatory" — the read is one-sided.
- Never a fertility, conception, "safe day", or pregnancy statement.
- Never an alarm or an instruction. The caption
  (`passivePhaseNote`, `prediction_format.dart`) describes a *pattern*
  ("your temperature pattern shows … which usually means you're past ovulation
  for this cycle"), always names itself an estimate, and always points at
  logging as the fix. Locked by `app/test/wearable/passive_phase_copy_test.dart`
  and redacted to a single neutral sentence under "Reduce spoken detail".
- No new schema, permission, dependency, CI gate, or network access.
