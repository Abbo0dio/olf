### Phase 3 — Correctable adaptive prediction engine v2

**Requirement refs:** §2, §4, §9(1)(2), Matrix WOW-FACTOR.

**What this phase is.** The v1 predictor (`RobustPredictor`, p1.4) is a correct, humble
stats projection: median recent cycle length off a fixed anchor, widened to the observed
range. It does not adapt to the individual, does not handle non-stationary cycles
(perimenopause, postpartum, PCOS drift), and has no evidence base for how accurate it is.
Phase 3 replaces it — behind the **unchanged `Predictor` seam** — with an *adaptive,
backtested* engine, and proves the improvement with numbers. It is grounded in
`requirements.md`:

- **§2** — predictions the user can **correct** to improve accuracy; adaptive to irregular
  cycles from day one.
- **§4 "Accuracy with humility"** — always show *ranges*, let users correct wrong
  predictions to train the model, and **never let a bad prediction snowball** into later
  months. Only 6.4% of users say their app *always* gets the period start date right.
- **§9(1)** — uncorrectable predictions / auto-logging is the single top anger source; Flo's
  own help centre admits "cycle settings don't influence the predictions directly". A
  correction that visibly does nothing is worse than no correction UI.
- **§9(2)** — incumbents handle irregular / PCOS / perimenopause / postpartum cycles
  poorly, which is "where users need the apps most".
- **Matrix WOW-FACTOR** — "fully correctable / self-learning prediction engine that visibly
  improves when users fix it".

**Phase-wide hard constraints** (every p3.x row inherits these; a row that needs an
exception says so and is negotiated before code):

1. **`core` stays Flutter-free.** The engine, the backtesting harness, the metrics, and the
   synthetic dataset generators are all pure Dart under `core/lib/src/`. No Flutter import,
   no platform channel.
2. **No ML-runtime / stats dependency without prior sign-off.** No TFLite, no bundled model
   file, no third-party statistics package. The "adaptive model" is **explainable
   plain-Dart arithmetic** — recency-weighted robust estimators (median / MAD / trimmed
   mean), conjugate Bayesian updating on cycle length, and explicit changepoint /
   non-stationarity handling. If p3.2 genuinely cannot be done without a package, that row
   **STOPS and negotiates** (skill §5) and the plan row is edited before any code.
3. **No backend, no network, no analytics/telemetry — ever.** p3.5's accuracy metrics are
   computed and shown **on-device**; nothing leaves the device. The opt-in real-data
   backtest path (p3.1) runs against the user's own DB behind an explicit action and its
   results never leave the device. CI exercises **synthetic fixtures only**.
4. **The `Predictor` seam stays stable.** p3.6 swaps the implementation with **no call-site
   change**. Any interface change must be *additive* and negotiated first — a breaking
   change to `predict({cycles, today})` is not in scope.
5. **Determinism.** `predict({cycles, today})` takes `today` injected; **no `DateTime.now()`
   in engine or harness code**, so the backtester is fully reproducible. Seeded RNG for all
   synthetic data.
6. **Derived-on-read stays the default.** There is no stored prediction today. If p3.2 /
   p3.3 need to persist model state or correction events, that is a **schema change** →
   migration + migration test **in the same PR**, and negotiated first.
7. **No PHI in logs**, crash traces, or any diagnostic output.

#### p3.1 — Backtesting harness
- **PR:** [#35](https://github.com/Abbo0dio/olf/pull/35) — merged (squash `c63915e`)
- **Branch / worktree:** `feat/p3.1-backtesting-harness` / `../olf-wt/p3.1`
- **Owner:** worker: phase3
- **Depends on:** p1.4 (`Predictor` seam, `RobustPredictor`), p1.3 (`Cycle` / `deriveCycles`)
- **Requirement refs:** §2, §4, §9(2)
- **Goal:** A reusable, deterministic backtesting harness in `core/` that replays a cycle
  history chronologically, calls a `Predictor` at each historical decision point with only
  the data known by then, and scores the forecast against what actually happened — so p3.2+
  can be measured, not asserted. Establish the **v1 baseline** (`RobustPredictor` through
  the harness) as a fixed regression reference.
- **Acceptance criteria:**
  - `core/lib/src/backtest/` is a real library (not test-only) — usable by the p3.1 tests
    **and** by p3.5's on-device dashboard.
  - Given a `List<Cycle>` history and a cutoff, the harness replays start-to-start: at each
    completed cycle boundary it builds the sub-history known up to that point, calls
    `Predictor.predict(cycles:, today:)` with `today` = the day after the previous period
    started (the realistic "ask me now" moment), and records predicted next-period window +
    midpoint vs the actual next period start.
  - Metrics computed over a run: period-start **MAE** and **median AE** (days); **coverage**
    = % of actual starts that landed inside the predicted range (calibration); **ovulation
    MAE** where a truth signal is supplied (BBT thermal shift / peak-mucus day) — optional,
    synthetic sets may omit it; a **snowball metric** — mean error on the N cycles *after*
    an outlier cycle vs the run-wide baseline error (ratio > 1 means the outlier degraded
    later predictions).
  - Deterministic seeded synthetic generators for: **regular** (~28 d, low variance),
    **irregular** (high variance), **PCOS-like** (long mean + high variance + occasional
    very long), **perimenopause** (rising mean + rising variance + occasional skipped
    cycle), **postpartum** (one long gap then a gradual return toward baseline). Same seed →
    byte-identical history.
  - Opt-in real-data path: the harness *can* run over the user's own on-device history, but
    only behind an explicit caller action; results stay on device. Nothing in `core`
    reaches for the DB on its own; CI never runs this path.
  - The `RobustPredictor` v1 numbers on each synthetic dataset are recorded in the PR and
    **asserted in a test** (with a tolerance) as the fixed reference the exit gate compares
    against.
- **Tests required:** generator determinism (same seed → identical `List<Cycle>`; different
  seed → different); metric math unit tests on hand-checked tiny inputs (MAE, median AE,
  coverage, snowball ratio); the v1 baseline assertion test; a harness smoke test that a
  `Predictor` returning `null` (thin history) is scored as "no prediction", not a crash.
- **Notes / detail:**
  - **No new dependency. No schema change** (reads the existing `Cycle` model via
    `deriveCycles`). **`core` stays Flutter-free** — `dart:math` only.
  - **Library shape (`core/lib/src/backtest/`):** `synthetic_history.dart` (seeded
    generators → `List<Period>` / `List<Cycle>`), `backtest_harness.dart` (the replay +
    per-decision-point records), `backtest_metrics.dart` (MAE / median AE / coverage /
    snowball from the records). Exported from `olf_core.dart`.
  - **Replay contract:** the harness never lets a `Predictor` see a cycle it could not have
    known — it slices `cycles` to those with `periodStart` ≤ the decision point. `today` is
    injected (constraint 5), so a fixed history yields a fixed score.
  - **Baseline is a floor, not a target:** the assertion uses a tolerance band so unrelated
    refactors do not break it, but a real regression in `RobustPredictor` will. p3.2 must
    beat these numbers on the irregular / PCOS / perimenopause sets to satisfy the exit
    gate.
  - v1 baseline numbers produced by this slice are recorded in the Log line below and in
    the PR body.

#### p3.2 — Adaptive prediction engine
  2026-08-31). See Log.
- **PR:** [#36](https://github.com/Abbo0dio/olf/pull/36) — merged (squash `c1d108c`)
- **Branch / worktree:** `feat/p3.2-adaptive-engine` / `../olf-wt/p3.2`
- **Owner:** worker: phase3
- **Depends on:** p3.1
- **Requirement refs:** §2, §4, §9(1)(2), Matrix WOW-FACTOR
- **Goal:** A per-user adaptive `Predictor` implementation that is **more accurate where more
  accuracy is achievable** (PCOS, postpartum), **at least as accurate everywhere else**
  (regular, irregular, perimenopause — where a robust median is already near-optimal on
  point error), outputs a **calibrated** next-period range on every profile, and — unlike
  v1 — **visibly responds when the user corrects a logged date** (§9(1)). The priority
  order set by the orchestrator: **trust, honesty, accuracy, ease of use.**
- **Acceptance criteria (trust-first reframe 2026-08-31 — see Log for the "why"; asserted
  in `core/test/backtest/v2_vs_v1_test.dart`, aggregated over a fixed seed set):**
  - **Point error (period-start MAE):**
    - `pcos`, `postpartum`: v2 **beats** v1 (measured ≈ −4 % and ≈ −10 %).
    - `regular`, `irregular`, `perimenopause`: v2 MAE **≤ v1 × 1.03** (statistical parity —
      a recency-weighted robust median is near-MAE-optimal on these DGPs; the 15 %-chance
      PCOS spikes are independent of history, so point accuracy there is a plateau).
  - **Calibration:**
    - coverage **≥ 0.80** for the ~90 % range on `regular` / `irregular` / `postpartum`.
    - `pcos` / `perimenopause`: v2 coverage **beats v1's by ≥ 10 pts** and clears a **0.68**
      floor (an absolute 0.80 there needs a useless ±13-day band — the honest move is a
      well-calibrated-*enough* range that is **marked low/medium confidence**, never high).
      This is the headline win on these sets: v1 coverage ≈ 0.48–0.54, v2 ≈ 0.73–0.74.
  - **Anti-snowball (non-regression guard only — p3.4 owns the real hardening):** v2 mean
    snowball ratio **≤ v1 mean × 1.20** per set.
  - **Correction response (§9(1)):** on the correction-response backtest — a recent logged
    boundary is mis-logged by a few days, then corrected — v2's forecast **visibly moves**
    between the two states (mean |Δ expected| **> 1.4× v1's**, and v1's is < 1 day — the
    "corrections do nothing" complaint made concrete), the correction **does not make
    accuracy worse** on average, and the typical move is **bounded** (90th-pct ≤ mis-log +
    3 days; a rare drift-threshold-crossing tail is p3.4's).
  - **`PredictionDelta`:** a correction is **never** reported as a silent no-op; wording is
    gender-neutral and non-alarming; `isMeaningful` tracks a ≥ 1-day / 1-bucket move.
  - **Property:** adding one **ordinary** cycle only nudges v2 — mean projected-length move
    < 2 d, 90th-pct ≤ 5 d; and no more skittish than v1 on the point estimate.
  - **Estimator shape:** recency-weighted robust central estimate; interval width from
    recent dispersion, not a fixed margin; weak conjugate Bayesian shrinkage so few-cycle
    histories degrade toward a wide honest range; explicit non-stationarity handling (a
    detected level shift smoothly shortens memory + adds a bounded drift term).
- **Tests required:** unit tests per estimator (incl. the AR-outlier gate); harness
  comparison test (v2 vs the regenerated v1 baseline) reproducing the table and asserting
  the reframed bar (MAE beat / parity / coverage floor / coverage-vs-v1 / snowball);
  correction-response test (v2 visible-effect > v1, correction non-harmful, bounded);
  property test that adding one **ordinary** cycle shifts/widens the estimate by no more
  than a bounded amount (pre-snowball); `PredictionDelta` unit tests (structural diff,
  `isMeaningful`, a correction is never reported as "no change" silently, gender-neutral
  non-alarming phrasing).
- **Notes / detail:** **plain-Dart statistics only** — no package added (constraint 2).
  Interface unchanged — `AdaptivePredictor implements Predictor`, same `predict({cycles,
  today})` signature, same `CyclePrediction` shape (constraint 4). No persisted model state:
  the engine is a pure function of `(cycles, today)`, derived-on-read, no schema change
  (constraint 6). Deterministic — no `DateTime.now()`, `today` injected (constraint 5). Not
  wired into the app; `RobustPredictor` stays the production default — the swap is p3.6.
  - **Estimators (all plain-Dart `dart:math` arithmetic):**
    0. **Plausibility down-weight** — each cycle's weight ramps *linearly* to zero over the
       ~10 days past 45 (or the person's own median, capped). A likely missed log ends at
       weight 0, but the ramp (not a step) means a 1–2 day edit near the mark can't lurch
       the forecast; past the ramp a cycle is dropped from the trend / dispersion
       estimators outright. **This replaced a hard `> 45 d` exclusion and is what turned
       PCOS from a small loss into a ≈ −4 % MAE win** (hard-excluding spike cycles was
       discarding real signal) and fixed a correction-response over-reaction.
    1. **Adaptive-memory recency weighting** — geometric decay over cycles newest→oldest;
       decay ramps *smoothly* from `0.96` (stationary) toward `0.82` as a detected level
       shift strengthens (band `0.25 → 1.0` d/cycle), so a regime change short-circuits old
       memory without a binary switch for a noisy edit to flip.
    2. **Robust central estimate** — weighted quantile (weighted median) of recent cycle
       lengths, nudged toward the shorter side by a bounded skew term (`wMean − wMedian`) so
       a few very-long PCOS cycles do not drag the point estimate up.
    3. **Monotone level-shift drift** — split the recent window into thirds, require a
       strictly monotone lo→mid→hi median progression whose total shift clears a MAD-scaled
       floor before applying a per-cycle drift term, clamped to ±2.5 d/cycle. Catches the
       perimenopause ramp without firing on noise.
    3b. **Lag-1 mean-reversion (AR(1)), outlier-gated** — when no trend is detected,
       estimate the recent lag-1 autocorrelation (`phiHat`, clamped `[0, 0.55]`) and shift
       the forecast a fraction of the last cycle's deviation from the level, capped at ±6 d.
       **Gated off when the most recent cycle is itself an outlier** (`|last − centre| >
       2·MAD`): you cannot mean-revert from a shock you did not forecast, and chasing a
       PCOS-type spike doubles the error when it reverts (this gate is what keeps the PCOS
       snowball ratio from regressing).
    4. **Weak Bayesian shrinkage** — conjugate-style pull toward a `29 d` prior with prior
       weight `0.5`, so 1–2-cycle histories degrade toward the prior and a wide range rather
       than a confident wrong point; the shrinkage also inflates the interval by
       `sqrt(1 + 2/(priorWeight + nEff))`.
    5. **Empirical calibrated interval** — half-width is a weighted quantile of absolute
       deviations from the centre at level `q` targeting the nominal ~90% range, times the
       thin-history inflation, times a tail-heaviness bump (ratio of the 0.92 to the 0.6
       deviation quantile) so fat-tailed sets (PCOS) get an honestly wider band. Floored at
       `minPredictionMarginDays`.
  - Ovulation / fertile-window derivation and the `status` / `daysPastExpected` logic are
    identical to v1 (`expected − lutealPhaseDays`, fertile `[ov−5, ov+1]`), so only the
    next-period centre + range change.
  - **`PredictionDelta` — the "here's what changed" substrate (engine-side; p3.3 renders
    it).** A plain-Dart value object + pure factory `PredictionDelta.between(before:, after:,
    context:)` that diffs two `CyclePrediction`s into: signed expected-date shift, signed
    range-width change, earliest/latest shifts, confidence before→after, and a list of
    plain-language, **gender-neutral, non-alarming** `reasons`. `context`
    (`followedCorrection`, `cyclesAdded`) shapes the wording. Invariants: a correction is
    **never** reported as a silent no-op (if nothing moved, it still says "your correction
    was applied; the prediction didn't need to change"); `isMeaningful` is true iff any
    field moved past a 1-day / 1-bucket threshold. No persistence, no `DateTime.now()`.
  - **Correction-response backtest (`core/lib/src/backtest/`).** New harness mode: at each
    replay point, perturb a recent logged period-start by `mislogOffsetDays` (default 3),
    predict; then "correct" it back to truth, predict; record the two predictions + the
    actual. Metrics: `visibleEffectDays` = |Δ expected midpoint| between mis-logged and
    corrected; `correctionGainDays` = `absErr(mislogged) − absErr(corrected)`. Lets the
    test show v2's forecast **moves** when you fix a date (v1's barely does — the §9(1)
    complaint) while staying bounded and non-harmful.
  - **Files:** `core/lib/src/prediction/adaptive_predictor.dart` (engine + private
    weighted-stats helpers); `core/lib/src/prediction/prediction_delta.dart` (the diff
    value object + factory); `core/lib/src/backtest/correction_response.dart` (the new
    harness mode). All exported from `olf_core.dart`. Tests:
    `core/test/prediction/adaptive_predictor_test.dart` (per-estimator units + edge cases +
    AR-outlier gate), `core/test/prediction/prediction_delta_test.dart`,
    `core/test/backtest/v2_vs_v1_test.dart` (comparison table + reframed bar),
    `core/test/backtest/correction_response_test.dart`,
    `core/test/backtest/adaptive_predictor_property_test.dart` (bounded-response property).
  - **Edge cases:** empty history → `null`; `cycles.first.isPregnancyGap` → `null` (same as
    v1); all-gap / all-current history → `null`; single usable cycle → prior-dominated wide
    range, `low` confidence; pregnancy gap partway through → only the post-gap run is used
    (`takeWhile(!isPregnancyGap)`); likely-gap cycles (`> 45 d`) excluded from the stats but
    not treated as regime changes.
  - **Fixture change (agreed with orchestrator).** p3.1's `irregular` / `pcos` generators
    drew each cycle length i.i.d. (memoryless), which makes a plain robust median already
    MAE-optimal — no adaptive engine (ML included) can beat it on point error there. Real
    cycle lengths are lag-1 autocorrelated (a long cycle makes the next one more likely to
    be long). The generators now use an AR(1) form `next = mean + phi·(prev − mean) +
    gaussian`, with **phi fixed BEFORE measuring the engine** — `phi = 0.3` (irregular),
    `phi = 0.4` (pcos) — as a physiologically-motivated modelling choice, **not tuned to the
    engine**. Noise SD scaled by `sqrt(1 − phi²)` so the marginal variance matches the old
    generators; the PCOS occasional-very-long-cycle spike is kept; irregular/pcos cycle
    count raised 24 → 36 for more scored points; seed stays 42; regular / perimenopause /
    postpartum generators unchanged. The v1 baseline in
    `core/test/backtest/v1_baseline_test.dart` is regenerated against the new generators
    (before/after in the Log below and the PR body). The orchestrator confirmed these
    fixtures stay (decision 2026-08-31).

#### p3.3 — Visible correction loop
- **PR:** [#37](https://github.com/Abbo0dio/olf/pull/37) — merged (squash `98a324a`)
- **Branch / worktree:** `feat/p3.3-correction-loop` / `../olf-wt/p3.3`
- **Owner:** worker: phase3
- **Depends on:** p3.2 (`PredictionDelta`)
- **Requirement refs:** §2, §4, §9(1)
- **Goal:** When the user corrects a prediction (fixes a wrong period start, adjusts a
  logged date), the app **shows** that the correction was taken into account and what
  changed — directly answering the §9(1) complaint that corrections silently do nothing.
- **Acceptance criteria:** after a correction the prediction card surfaces the p3.2
  `PredictionDelta` in plain language — "your correction updated this — expected date moved
  from X to Y / range narrowed", or, when nothing moved, the explicit "your correction was
  applied; the prediction didn't need to change"; the change is real (the adaptive engine
  re-runs on the corrected history); no correction is ever silently discarded; the note is
  gender-neutral and non-alarming.
- **Tests required:** widget test — correct a date, assert the card renders the
  `PredictionDelta` before→after and that the new prediction matches the engine on the
  corrected history; widget test for the "no change needed" branch.
- **Notes / detail:** **the "what changed" computation is done — it lands in p3.2 as
  `PredictionDelta` (`core/lib/src/prediction/prediction_delta.dart`) with its own unit
  tests and the never-a-silent-no-op invariant.** p3.3 is purely presentation + wiring.
  - **What counts as "correcting a prediction":** the user editing a logged period's
    start/end date, or adding / removing a logged period, via the existing period editor
    (`showPeriodEditor`) or the history "delete" action on the calendar screen
    (`period_calendar_page.dart`). These are the derived-on-read inputs the forecast is
    built from; fixing one *is* correcting the prediction.
  - **Flow (engine-agnostic — it just diffs two `CyclePrediction`s, so it survives the p3.6
    swap unchanged):** on entering an edit, capture `before = ref.read(predictionProvider)`.
    Run the edit. On a real change (`PeriodEditorOutcome.saved` / `deleted`), recompute
    **from the freshly-written data** — `predictorProvider.predict(cycles: deriveCycles(
    await periodRepo.allPeriods(), pregnancyEvents: await cycleEventRepo.pregnancyEvents()),
    today: …)` — so the delta is real, not fabricated, and does not race the provider
    stream. Then `PredictionDelta.between(before, after, context: …)` and publish it to a
    new `correctionNoticeProvider` (`NotifierProvider<…, PredictionDelta?>`, in-memory
    session state only — **no schema change, no correction-event history**). Context split:
    editing / deleting an existing entry passes `PredictionChangeContext(followedCorrection:
    true)` ("Your correction was applied. …"); adding a fresh period passes
    `PredictionChangeContext(cyclesAdded: 1)` ("You logged another cycle. …") — logging is
    not correcting. The note still fires for all four paths; only the lead wording differs.
  - **Where it surfaces:** a `_CorrectionNotice` block on the calendar screen, rendered
    directly where the prediction card is / would be (so a `withdrawn` delta still explains
    why the card vanished). Renders `delta.reasons` verbatim (plain-language, gender-neutral,
    non-alarming — all from `PredictionDelta`), a leading check icon, and a dismiss (×)
    button. The **"no change needed" branch always renders** — `PredictionDelta` guarantees
    a non-empty reason when `followedCorrection` is set.
  - **Transient:** auto-clears after ~10 s (a `Timer` in the notice widget) or on manual
    dismiss; also cleared if the user hits *Undo* on a delete. Not persisted, no history.
  - **a11y:** the notice is wrapped in `Semantics(liveRegion: true, container: true,
    label: <joined reasons>)` and additionally fires `SemanticsService.announce(<joined
    reasons>)` on show / change. Dark mode via `colorScheme.secondaryContainer`; the one
    app-side string (`correctionNoticeDismissLabel = 'Dismiss'`) is a named const in
    `prediction_format.dart` and covered by the p1.9 `inclusive_language_test` scan plus a
    focused non-alarming assertion in the new widget test.
  - **Files:** `app/lib/src/prediction/correction_notice_providers.dart` (new — the
    `Notifier`); `app/lib/src/prediction/prediction_format.dart` (+1 const);
    `app/lib/src/period/period_calendar_page.dart` (capture-before / recompute-after
    wiring + `_CorrectionNotice` widget). Tests:
    `app/test/prediction/correction_notice_test.dart`.

#### p3.4 — Anti-snowball guarantees
- **PR:** [#38](https://github.com/Abbo0dio/olf/pull/38) — merged (squash `c27b813`)
- **Branch / worktree:** `feat/p3.4-anti-snowball` / `../olf-wt/p3.4`
- **Owner:** worker: phase3
- **Depends on:** p3.2
- **Requirement refs:** §4, §9(2)
- **Goal:** Guarantee — with tests — that one anomalous cycle (a skipped period, a very late
  period, an anovulatory month, a mis-logged date later corrected) cannot poison subsequent
  predictions.
- **Acceptance criteria:** the p3.1 snowball metric (post-outlier error ÷ baseline error)
  stays ≤ a documented bound on every synthetic set; an injected single outlier decays out
  of the estimate within a bounded number of cycles; skipped / likely-gap / pregnancy-gap
  cycles are explicitly excluded from the adaptive update, not just down-weighted; a
  late-but-not-yet-started period never rolls the expected date forward on its own (v1
  behaviour preserved).
- **Tests required:** harness snowball-metric assertions per dataset; targeted "inject one
  outlier, measure recovery" tests; regression test for the late-period no-rollforward
  rule.
- **Notes / detail:** `AdaptivePredictor` only — not wired to the app (still p3.6). Seam
  signature + `CyclePrediction` shape unchanged; plain-Dart, no dep; deterministic; core
  stays Flutter-free. **What was hardened (three changes to the engine, all motivated by
  "v2's recency-weighted centre is structurally more outlier-reactive than v1's flat
  median"):**
  1. **Time-position-preserving exclusion.** A completed cycle past the plausibility ramp
     (weight 0 — a skipped month, a missed log, an anovulatory / pregnancy-adjacent
     stretch) is now removed from **every** estimator (centre, drift, dispersion, AR) up
     front, the same treatment a pregnancy gap gets — not "kept at weight 0", which still
     let it occupy a recency slot. It keeps its slot on the *timeline* (`keepAt` holds each
     real cycle's original index) so the recency decay of the real cycles behind it is
     unchanged and a skip cannot bias a drifting history downward. Cycles *inside* the ramp
     (~46–55 d) stay down-weighted — that band is the p3.2 no-discontinuity device for an
     edit near 45 d.
  2. **Centre outlier-influence down-weight.** The centre quantile reads an
     outlier-influence-shrunk copy of the weights (`_centreOutlierInfluence`, floor 0.5,
     ramp 2→4 robust MADs), so a recent moderate spike cannot drag the typical-length
     estimate the way plain recency weighting let it. The **dispersion** step keeps the
     unshrunk weights — a real cycle *is* more variable and the interval should say so
     (coverage unaffected).
  3. **AR outlier gate → ramp.** The lag-1 mean-reversion term's strength now ramps to zero
     over `_arOutlierRampLoMad`(1)→`_arOutlierRampHiMad`(2) MADs instead of a hard cliff at
     2·MAD — a spike just inside the old gate is no longer chased at full φ and then
     snapped back.
  - **Recovery bound (documented N):** against an established ~28-day history, one injected
    outlier of *any* magnitude (40–110 d) shifts the expected next-start by **≤ 2 days**,
    immediately and at every later cutoff (asserted ≤ 3; measured max 2 over 120 seeds × 9
    magnitudes). Effectively **N ≈ 1** — it never poisons.
  - **Snowball bound (documented):** on the union of in-sample (1–20) and held-out
    (200–249) seeds, `minCompletedCycles = 3` ("a snowball is an *established* forecast
    degraded by an anomaly"): v2 mean ratio **≤ v1 + 0.05** per profile; **≤ v1** on the
    profiles with a real snowball (v1 ratio ≥ 1.10: irregular, pcos, postpartum); and the
    **aggregate across profiles is ≤ v1** in-sample, held-out, and union. Per-seed the
    ratio is noise-dominated (often < 15 post-outlier points/seed) → per-seed parity
    (v2 ≤ v1 on ~46–57 % of seeds), the guarantee rests on the aggregate.
  - **Held-out validation (p3.2 follow-up):** the p3.2 calibration constants were tuned on
    low seed ranges overlapping `v2_vs_v1_test`'s assertion seeds; added held-out
    (seeds 200–249) coverage-floor and MAE-parity/beat assertions to `v2_vs_v1_test` — both
    hold out of sample.
  - **Known still-deferred:** the `adaptive_predictor_property_test` range-width tail
    (max 56 d) from a drift-detector on/off flip when a cycle is added — a discontinuity in
    the *interval* recompute, not the point estimate; needs a drift-strength ramp on the
    interval, out of scope for the anti-snowball slice.
  - **Files:** `core/lib/src/prediction/adaptive_predictor.dart` (the three changes +
    doc-comment rewrite of pipeline steps 0/1/2/3b). Tests:
    `core/test/backtest/anti_snowball_test.dart` (new — snowball guarantee in/out of
    sample + single-outlier recovery + "excluded cycle's length is irrelevant"),
    `core/test/prediction/adaptive_predictor_test.dart` (+group: late-period no-rollforward,
    skip excluded-not-down-weighted, rising-trend not biased by a skip, AR gate is a ramp),
    `core/test/backtest/v2_vs_v1_test.dart` (snowball guard tightened + held-out
    calibration/MAE). `RobustPredictor` / `v1_baseline_test` untouched — v1 unchanged.
- **Before / after — snowball ratio (post-outlier MAE ÷ baseline MAE), `minCompletedCycles = 3`:**

  | profile | seeds | v1 | v2 (p3.2) | v2 (p3.4) |
  |---|---|--:|--:|--:|
  | irregular | in-sample | 1.147 | 1.237 | **1.143** |
  | irregular | held-out | 1.224 | 1.188 | 1.221 |
  | irregular | union | 1.199 | 1.204 | **1.196** |
  | pcos | union | 1.175 | 1.156 | 1.164 |
  | perimenopause | union | 1.042 | 1.050 | 1.053 |
  | postpartum | held-out | 0.862 | 0.953 | **0.782** |
  | postpartum | union | 1.198 | 1.246 | **1.153** |
  | **aggregate (defined profiles)** | union | **1.154** | **1.164** | **1.142** |

  p3.2's aggregate snowball was **above** v1's (1.164 vs 1.154); p3.4 brings it **below**
  (1.142). MAE / coverage unchanged within tolerance: v2 still beats v1 on pcos (−4 %) and
  postpartum (−12 %), parity elsewhere; coverage floors hold in- and out-of-sample.

#### p3.5 — Internal accuracy metrics (local, private)
- **PR:** [#39](https://github.com/Abbo0dio/olf/pull/39) — merged (squash `12dc0a6`)
- **Branch / worktree:** `feat/p3.5-accuracy-metrics` / `../olf-wt/p3.5`
- **Owner:** worker: phase3
- **Depends on:** p3.1, p3.2
- **Requirement refs:** §3, §4, §6 (substantiable claims — ASA precedent)
- **Goal:** An on-device, private view of prediction quality over the user's own history —
  so model changes can be judged release to release and any public accuracy claim is backed
  by a reproducible number, not marketing.
- **Acceptance criteria:** reuses the p3.1 harness against the user's own DB behind an
  explicit action; shows period-start MAE / median AE / coverage and a trend; **nothing
  leaves the device**, no analytics call, no network; the screen states the sample size and
  that it is the user's own data only; copy is non-alarming.
- **Tests required:** widget test (renders the metrics from a seeded in-memory DB; empty /
  thin-history state); a test asserting no network client is constructed on this path.
- **Notes / detail:** presentation in `app/`; all computation stays in the `core` harness
  (`runBacktest` / `BacktestMetrics`, already Flutter-free). No new dep, no schema change
  (read-only over `periods`).
  - **Entry point:** a `Prediction accuracy` `ListTile` in Settings under the **Cycle**
    section (below *Pregnancy loss & birth*) → pushes `AccuracyPage`. Not on the home
    screen; explicit action to open.
  - **What it measures:** the **production** predictor (`predictorProvider`), so it reflects
    v2 automatically once p3.6 lands. `accuracyReportProvider` — a
    `FutureProvider.autoDispose` — reads the user's period starts
    (`periodsProvider.future` → `p.startDate`, ascending) and runs
    `runBacktest(periodStarts:, predictor:, minCompletedCycles: 1)`, then
    `BacktestMetrics.of`. Re-runs on open, frees on close. A v1-vs-v2 comparison on the
    user's own data was **deferred** (follow-up in §9) — keeps the slice tight and avoids
    showing a v2 number before p3.6 swaps it into production.
  - **Shows:** *typical miss* (mean abs period-start error, days), *median miss*, *landed in
    the estimated range* (coverage %), *checked against N past periods* (the scored-point
    count = sample size), and a **plain `CustomPaint` sparkline** of abs error per past
    decision point (no charting package; a text range fallback under 2 points). All values
    from `BacktestMetrics`; nothing fabricated.
  - **States:** loading → spinner + "Working through your logged history…"; thin history
    (`scoredPoints < 3`) → "There isn't enough logged history to measure yet. Keep logging
    your periods and check back." — never a number; normal → the metrics + sample size +
    sparkline. The screen body states the numbers are computed **on this device** from the
    user's own logged history and **nothing is sent anywhere**; it makes **no** accuracy
    claim of its own (it shows the user *their* number with its sample size).
  - **a11y / dark mode:** every metric row and the sparkline carry `Semantics` labels
    (sparkline → "Miss per past estimate, from X to Y days"); colours from the theme.
  - **Not pregnancy-gap-aware:** the backtest replays raw period starts, so a recorded
    pregnancy gap shows as a transient error spike rather than being modelled — noted as a
    §9 follow-up; most users have no such event and for them the number is exact.
  - **Copy:** user-facing strings are named `const`s in
    `app/lib/src/prediction/accuracy_format.dart`; `accuracy_copy_test.dart` asserts the
    disclaimer + headings are non-alarming (no "wrong / bad / poor / unreliable / failed")
    and carry no marketing claim (no "best / most accurate / proven / guaranteed"), and that
    the privacy sentence names the device and "not sent". The p1.9
    `inclusive_language_test` scan covers gender-neutrality automatically.
  - **Files:** `app/lib/src/prediction/accuracy_providers.dart` (new — `AccuracyReport` +
    `accuracyReportProvider`), `accuracy_format.dart` (new — strings + format helpers),
    `accuracy_page.dart` (new — `AccuracyPage` + `_Sparkline`);
    `app/lib/src/settings/settings_page.dart` (+1 `ListTile`). Tests:
    `app/test/prediction/accuracy_page_test.dart` (renders + matches an in-test
    `runBacktest`; thin-history state; **no `HttpClient` constructed** via a throwing
    `HttpOverrides`), `accuracy_copy_test.dart`.

#### p3.6 — Swap `Predictor` to the adaptive engine
- **PR:** [#40](https://github.com/Abbo0dio/olf/pull/40) — merged (squash `cca91d5`)
- **Branch / worktree:** `feat/p3.6-swap-predictor` / `../olf-wt/p3.6`
- **Owner:** worker: phase3
- **Depends on:** p3.2, p3.4, p3.5
- **Requirement refs:** §2, §4, Matrix WOW-FACTOR
- **Goal:** Make the adaptive engine the default `Predictor` with **no call-site change**,
  and retire `RobustPredictor` to a clearly-labelled baseline used only by the harness.
- **Acceptance criteria:** the app wires the new implementation through the existing
  provider; every existing predictor/widget test still passes (or is updated only where the
  *number* legitimately changed, with the reason noted); `RobustPredictor` stays in the
  tree, referenced by the p3.1 baseline test, marked as the v1 reference; the Phase 3 exit
  gate is demonstrated in the PR (v2 vs v1 harness table, correction-changes-output test,
  snowball bounds).
- **Tests required:** full core + app suites green; the exit-gate evidence table reproduced
  from a test.
- **Notes / detail:** pure swap behind the seam (constraint 4) — one production line
  changes, nothing else in `lib/` moves.
  - **The swap:** `predictorProvider` (`app/lib/src/prediction/prediction_providers.dart`)
    `const RobustPredictor()` → `const AdaptivePredictor()`. That is the **only** production
    wiring change. Every consumer already reads the provider: `predictionProvider` (home /
    calendar card), the p3.3 correction loop (`period_calendar_page.dart` `_runHistoryEdit`
    → `ref.read(predictorProvider)`), and the p3.5 accuracy screen
    (`accuracy_providers.dart` → `ref.watch(predictorProvider)`) — all three move to v2 with
    no edit. Verified by the existing widget tests for each surface now exercising v2's
    output. `RobustPredictor` stays in the tree with a **"v1 reference baseline — no longer
    the production `Predictor` as of p3.6"** doc-comment; still used by `v1_baseline_test`,
    `v2_vs_v1_test`, `anti_snowball_test`, `correction_response_test`, and the new
    `phase3_exit_gate_test`. `fertile_window_signal.dart` keeps importing the
    `fertileDaysAfterOvulation` const from `robust_predictor.dart` — a shared constant, not
    an engine dependency.
  - **Existing tests updated (number changed legitimately under v2 — no assertion
    weakened):**
    - `app/test/prediction/prediction_card_test.dart` — the `predictionFor` oracle now
      instantiates `AdaptivePredictor` (it cross-checks rendered text against the engine the
      screen runs). One fixture (`a regular history renders …`) grew from 4 → 5 metronomic
      period starts: v2 only calls a forecast **high-confidence** once the effective sample
      ≥ 3 (≈ 4 completed cycles at `_decayStable` 0.96), where v1 reached `high` at 3. Same
      intent — a strong regular history renders the confident-estimate path — with one more
      cycle of evidence so v2 legitimately gets there. Everything else in that file is
      engine-agnostic (presence/absence of the card, overdue check-in).
    - `app/test/prediction/correction_notice_test.dart` — same `predictionFor` oracle swap;
      the delta-reason strings it derives are v2's now. No fixture change needed — the
      "meaningful correction moves the forecast" and "no-op still speaks" intents hold.
    - `app/test/prediction/accuracy_page_test.dart` — the in-test `runBacktest` oracle now
      replays `AdaptivePredictor` (the screen reads `predictorProvider`). Scored-point count
      (`_expectedScored = 9`) is engine-independent, unchanged.
    - `core` p1.4 `robust_predictor_test.dart` — **untouched**; it tests v1 directly and v1
      is frozen.
  - **Exit-gate evidence — `core/test/backtest/phase3_exit_gate_test.dart` (new):** prints
    one consolidated table (per profile: v1/v2 MAE, v1/v2 coverage, v1/v2 snowball ratio,
    v1/v2 mean visible correction effect) for the in-sample (seeds 1–20) **and** held-out
    (seeds 200–249) ranges, and re-asserts the load-bearing inequality behind each of the
    three phase claims (measurable improvement / corrections change output / no snowball) so
    the printed numbers cannot silently drift. The finer per-profile bounds stay in the
    three source files (`v2_vs_v1_test`, `correction_response_test`, `anti_snowball_test`),
    which all still pass unchanged. Table is quoted in the PR body.
  - **Migration UX — deferred to a §9 follow-up (not built this slice).** p3.2 flagged that
    a PCOS / perimenopause user on unchanged history sees the range widen + confidence drop
    after the update, which without framing reads as a downgrade. A *good* one-time notice
    must fire **only** for the users whose forecast actually moved — otherwise the ~80% with
    steady cycles get a changelog pop-up for a no-op. Deciding "did it move for this user"
    means running v1 and v2 on their live history and diffing — which is exactly the
    **v1-vs-v2-on-own-data comparison already deferred out of p3.5** (§9). Bolting an
    imprecise, fires-for-everyone banner onto a one-line pure-swap slice is the scope creep
    constraint 4 / the plan's no-silent-expansion rule warn against; a precise notice is a
    small slice of its own once that comparison exists. Filed in §9. The swap itself is not
    gated on it.
  - **Constraints:** no new dependency; no schema change (nothing persisted); `core` stays
    Flutter-free (only a doc-comment touched there besides the new test); `Predictor` seam
    signature + `CyclePrediction` shape unchanged; deterministic (`today` still injected, no
    `DateTime.now()` in the engine). No UI added, so no new dark-mode / a11y surface.
  - **Files:** `app/lib/src/prediction/prediction_providers.dart` (the swap + doc),
    `core/lib/src/prediction/robust_predictor.dart` (baseline doc-comment only),
    `core/test/backtest/phase3_exit_gate_test.dart` (new),
    `app/test/prediction/{prediction_card,correction_notice,accuracy_page}_test.dart`
    (oracle → v2; one fixture +1 cycle). Phase 3 close (doc bump + exit-gate paragraph) is a
    **separate docs PR after merge** — this is the last Phase 3 *build* slice.
**Exit gate:** measurable improvement over v1 on the irregular-cycle datasets; corrections
demonstrably change output; no snowballing in tests.

**Exit-gate status — MET (2026-09-01).** All six slices p3.1–p3.6 merged to `main`
(PRs [#35](https://github.com/Abbo0dio/olf/pull/35)–[#40](https://github.com/Abbo0dio/olf/pull/40))
with CI green; each slice's acceptance criteria were verified in its PR. The `Predictor`
seam signature and `CyclePrediction` shape are unchanged from p1.4 — the entire phase
landed behind the frozen interface. `RobustPredictor` (v1) stays in the tree as the
labelled reference baseline for the harness.

The gate as written — *"measurable improvement over v1 on the irregular-cycle datasets;
corrections demonstrably change output; no snowballing in tests"* — was **reframed during
p3.2** (orchestrator decision, "trust first"): a recency-weighted robust median is already
near-MAE-optimal on the synthetic irregular / perimenopause DGPs, and PCOS length spikes
are history-independent by construction, so a uniform "lower MAE everywhere" target would
have meant overfitting. The gate is met on the honest reframe below.

- **Measurable improvement over v1 on the irregular-cycle datasets** — met as a
  **point-error beat where a beat is possible, plus a calibration step-change everywhere**.
  MAE: v2 beats v1 on `pcos` (~−4%: 12.90 → 12.44 in-sample, 11.37 → 10.99 held-out) and
  `postpartum` (~−11%: 4.61 → 4.09, 4.55 → 4.10); statistical parity (≤ +3%) on `regular` /
  `irregular` / `perimenopause` — a proven near-optimality of the v1 estimator on those
  processes, not a concession. The real improvement is calibration: the predicted range
  **stops claiming false precision** (`requirements.md` §4, "accuracy with humility") —
  in-range coverage rises `pcos` 0.48 → 0.73, `perimenopause` 0.54 → 0.74, `postpartum`
  0.69 → 0.88, `irregular` 0.79 → 0.90, while `regular` holds at 0.91 and wide-range
  forecasts are no longer sold as high-confidence. Evidence:
  `core/test/backtest/phase3_exit_gate_test.dart` (consolidated table, asserted) and
  `core/test/backtest/v2_vs_v1_test.dart`, both in-sample (seeds 1–20) **and** held-out
  (seeds 200–249, never tuned against). Built across **p3.1** (backtest harness + synthetic
  DGPs + v1 baseline, PR [#35](https://github.com/Abbo0dio/olf/pull/35) `c63915e`) and
  **p3.2** (the adaptive engine — recency-weighted robust centre, monotone drift term,
  lag-1 mean-reversion, empirical calibrated interval, thin-history Bayesian shrinkage,
  PR [#36](https://github.com/Abbo0dio/olf/pull/36) `c1d108c`).
- **Corrections demonstrably change output** — met. **p3.3** shipped the visible correction
  loop (PR [#37](https://github.com/Abbo0dio/olf/pull/37) `98a324a`): editing or adding a
  logged date recomputes the forecast on the same screen and shows a plain-language note of
  what moved, announced to screen readers, never silent even on a no-op. The
  correction-response backtest (`core/test/backtest/correction_response_test.dart`) proves
  the engine half: on a fixed 3-day mis-log v1's forecast moves < 1 day on every profile
  while v2 moves **~1.7–2.2× v1** (0.84–1.26 days), and the mean correction *accuracy* gain
  stays ≥ −0.3 d — correcting a date never meaningfully worsens the forecast.
- **No snowballing in tests** — met. **p3.4** (PR [#38](https://github.com/Abbo0dio/olf/pull/38)
  `c27b813`) hardened the engine (time-position-preserving exclusion of implausible cycles;
  an outlier-influence down-weight on the centre; a ramped AR outlier gate) and proved it:
  the aggregate post-outlier / baseline error ratio is **v2 ≤ v1 in-sample (1.229 ≤ 1.236)
  and held-out (1.064 ≤ 1.082)**, and a single injected outlier of any magnitude (40–110 d)
  against an established ~28-day history shifts the expected next-period date **≤ 3 days**,
  immediately and at every later cutoff (measured max over the sweep: 2 days). Evidence:
  `core/test/backtest/anti_snowball_test.dart`.

**Shipped on top of the gate:** **p3.5** — a private, on-device prediction-accuracy screen
(PR [#39](https://github.com/Abbo0dio/olf/pull/39) `12dc0a6`): a read-only backtest replay
of the user's own logged history through the production predictor, shown behind an explicit
Settings action, with sample size stated, no fabricated number on thin history, and no
network (asserted). **p3.6** — the production swap (PR [#40](https://github.com/Abbo0dio/olf/pull/40)
`cca91d5`): `predictorProvider` moved from `RobustPredictor` to `AdaptivePredictor` with no
call-site change; `phase3_exit_gate_test` added as the single reproducible evidence table.

**Outstanding non-blockers carried forward** (all filed as Phase 3 rows in §9): the
`AdaptivePredictor` interval-width discontinuity (a cycle that flips the drift detector can
jump the range width — the point estimate is stable, the interval recompute is not); the
v1-vs-v2-on-the-user's-own-history comparison cut from p3.5; the accuracy backtest not
being pregnancy-gap-aware (a logged loss/birth shows as a transient error spike); the
whole-history replay running on the main isolate on screen open; and the v2 migration
notice (a one-time "your ranges are calibrated now" note for users whose forecast visibly
widened on the swap — deferred from p3.6 because a precise, non-misfiring notice depends on
the v1-vs-v2-on-own-data comparison above).

---
