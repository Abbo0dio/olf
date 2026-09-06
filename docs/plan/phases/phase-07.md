### Phase 7 — Life-stage & condition modes

**Requirement refs:** §2 (condition-specific modes; perimenopause/menopause; pregnancy & TTC;
cycle-return/postpartum; explicit loss/birth events), §9(2) (poor handling of
irregular/PCOS/perimenopause/postpartum cycles — "where users need the app most"), §9(3) (no
loss / "gave birth" logging), §9(12) (no alarming automated "diagnoses"), §6 (not a medical
device — disclaimers on every mode).

**What this phase is.** olf already tracks cycles, flow, symptoms, BBT/mucus, meds/BC and
pregnancy-loss/birth events (Phase 1), predicts with a correctable engine (Phase 3), and can
hand a clinician a report (Phase 6). Phase 7 adds **opt-in modes** — each a focused lens on the
same underlying data for a life stage or condition: postpartum cycle-return, pregnancy, TTC,
PCOS, endometriosis, PMDD, perimenopause, and birth-control switching. A mode changes what the
app *surfaces and asks about*, never the core logging model.

**Phase-wide constraints.**
- **Free.** Per foundational principle §5 (free forever), every mode's logging *and* its
  correlation/insight views ship free. The Phase 7 stub's "insights may later be paid (Phase
  10)" line is **superseded** — do not gate anything.
- **`core` stays Flutter-free / `DateTime.now()`-free.** Every derivation a mode needs — a daily
  fertility score, a symptom-vs-cycle-phase correlation, a perimenopause variability score, a
  postpartum cycle-return estimate — lives in `core` as pure, clock-injected Dart. The mode
  *screens* live in `app`.
- **Opt-in and reversible.** A mode is off by default, turned on from one place (Settings →
  "Modes", or a prompt tied to a logged event — e.g. a birth event offers postpartum mode),
  and turning it off never deletes data. No mode clutters the default home/calendar for a user
  who hasn't enabled it.
- **No diagnosis, no alarm (§9(12)).** A mode shows *your* patterns ("days you logged cramps
  cluster in your luteal phase"), never a verdict ("you have endometriosis") or a directive
  ("ask your doctor about PCOS"). Every mode screen carries the standard "not a medical device"
  line. Copy goes through the p1.9 inclusive-language seam and the p4.3 sensitive-copy
  discipline.
- **Reuse, don't fork.** Modes build on existing tables and engines: p1.11 pregnancy events,
  p1.5 symptoms + custom symptoms, p1.6 BBT/cervical-mucus, p3 `AdaptivePredictor`, p1.3
  `deriveCycles` / `CycleStats`. A mode that genuinely needs a new table or column is a
  **schema change** — §5 stop, and it ships with its migration + `migration_matrix_test`
  extension + backup round-trip in the same PR (the p6.1 precedent; `docs/release-checklist.md`
  "Schema change" block). Prefer a typed value in the existing `app_settings` KV or a custom
  symptom over new DDL where it fits.
- **One mode = one slice = one PR.** If a mode is too big for a reviewable PR (pregnancy mode
  is the likely candidate — week-by-week content + a symptom set), the Worker splits it
  (`p7.2a` / `p7.2b`) at negotiation time, not silently.
- **Modes are independent.** No ordering dependency between p7.2–p7.8; p7.1 is sequenced first
  because it hardens the p1.11 event path the others lean on. Any shared surface (a "Modes"
  settings section, a mode-enablement provider, a correlation-chart widget) is built once in
  p7.1 and reused — note it in that row.

#### p7.1 — Pregnancy-loss / birth / postpartum flows + the mode framework
- **Depends on:** p1.11 (pregnancy events), p1.3 (`deriveCycles`)
- **Requirement refs:** §2 (cycle-return/postpartum; explicit loss/birth), §9(3), §9(2)
- **Goal:** after a user logs a pregnancy loss or a birth, olf offers a **postpartum mode** that
  tracks the return of the cycle (first bleed, first ovulation signs, cycle-length settling)
  instead of treating the gap as one long broken cycle; and gentle, non-prescriptive support
  resources appropriate to a loss vs. a birth. Also lands the **shared mode framework** the rest
  of Phase 7 reuses.
- **Acceptance criteria:**
  - A **mode-enablement seam**: a `core` notion of which modes are active (typed keys in
    `app_settings`, no schema change) + an `app` "Modes" section in Settings listing every
    Phase 7 mode with a one-line description and an on/off control; turning a mode off keeps all
    data.
  - Logging a p1.11 loss or birth event surfaces a **calm, dismissible** offer to turn on
    postpartum mode (never auto-enabled).
  - **Postpartum cycle-return view** (pure `core` derivation over the existing period +
    pregnancy-event history): time since the event, whether a first post-event period has been
    logged, and — once ≥ 2 post-event cycles exist — a "cycles are settling / still variable"
    read using p1.3's existing variability classifier. No new prediction engine; the p3
    predictor stays anchored on logged periods and is simply noted as "still settling" until
    enough post-event cycles exist. Honest `null` (no fabricated estimate) before then.
  - A **support-resources screen** whose content differs for loss vs. birth: general,
    non-clinical, no external links that phone home (bundled text; if any URL is shown it is
    plain text the user copies, not a tracked link). Carries the not-a-medical-device line and
    a line pointing to real care.
  - A **shared correlation-chart widget** stub in `app` (a cycle-phase-banded timeline the
    condition modes p7.4–p7.7 will fill) — built here so it gets one a11y sweep and one dark-mode
    pass, reused later. If it is not genuinely shareable yet, say so in the notes and defer it
    to p7.4 rather than shipping a hollow widget.
  - New `screen_nav.dart` surface(s); five a11y sweeps green; dark mode; `reduceSpokenDetail`
    applied to any sensitive counts.
  - `docs/threat-model.md`: note that postpartum/loss context is now a derived view over
    existing data classes — no new asset, no new egress.
- **Tests required:** `core` unit tests for the cycle-return derivation (no post-event period →
  honest "waiting" state; 1 cycle; ≥2 cycles settling vs. variable; a loss and a birth both
  handled; clock injected). `app` widget tests: the event → mode-offer flow (offer shown,
  dismissible, opt-in only), the Modes settings section (toggle on/off, data survives), the
  loss vs. birth resources screen renders the right copy, the cycle-return view states. Sweeps.
- **Notes / detail:** Worker owns the mode-key shape and whether the correlation-chart widget
  lands here or in p7.4. Keep the resources copy short and reviewed (p4.3 discipline). No new
  table unless the cycle-return view genuinely can't be derived — flag it if so.

#### p7.2 — Pregnancy mode (week-by-week + pregnancy symptom logging)

**Split at negotiation (2026-09-06, worker: 1) into p7.2a / p7.2b** — too big for one
reviewable PR (43-entry week-notes content asset + gestational-age core + a symptom set +
prediction-UI suppression). The split was pre-sanctioned in "Phase-wide constraints" above.

**Enablement — acceptance criterion altered at the same negotiation (Orchestrator approved
Option A).** As written the criterion said pregnancy mode is "offered when the user records a
positive pregnancy state via p1.11". p1.11 has **no** positive-pregnancy state —
`CycleEventType` is `{periodStart, pregnancyLoss, birth}`; adding a `pregnancyStart` /
`pregnancyConfirmed` type is a schema change (migration + `migration_matrix_test` + backup
round-trip) disproportionate to hanging an enable-offer on it, and out of p1.11's scope.
**Instead:** pregnancy mode enables from the Modes section only; the **start-reference input**
(LMP / user-entered due date / conception date), stored as a typed `app_settings` value
(p7.1 precedent, no schema change), *is* the "I'm pregnant" record. A p1.11 loss/birth still
ends it. "Offer pregnancy mode from a logged positive state" is deferred to a future slice
that adds a pregnancy-start event — see `backlog.md`.

- **Depends on:** p7.1 (mode framework), p1.11 (loss/birth end the pregnancy)
- **Requirement refs:** §2 (pregnancy mode — week-by-week development, symptom logging), §6

##### p7.2a — Gestational-age core + week view + enable/start-reference flow
- **Acceptance criteria:**
  - Pregnancy mode is enabled from the p7.1 Modes section. Turning it on collects a **start
    reference** — LMP, a user-entered due date, or a conception date — stored as a typed
    `app_settings` value (no schema change). That stored reference is the pregnancy record for
    p7.2; clearing the mode clears it.
  - Pure `core` `gestational_age.dart`: GA week + day and trimester from any of the three
    reference kinds, clock-injected (no `DateTime.now()` in `core`); a reference date in the
    future / an as-of date before conception → an **honest error, not a negative week**.
  - A **week view**: current gestational week + trimester, and a short bundled development note
    per week (`pregnancy_week_notes.dart`, 0–42 → 43 entries). Plain bundled text,
    **non-alarming, non-clinical**, carries the not-a-medical-device line, no tracked links,
    reviewed against p4.3. Explicitly *not* a medical timeline.
  - `modes_page` / `mode_catalog` wiring so the mode is reachable + shows its "Open" affordance
    when on. New `screen_nav.dart` surface(s); sweeps green; dark mode.
- **Tests required:** `core` gestational-age maths (from LMP; from due date; from conception
  date; week/trimester boundaries; pre-reference as-of date → honest error; clock injected).
  `app`: enable + start-reference flow, week view renders the right week + note, week-notes
  asset has all 43 entries. Sweeps.

##### p7.2b — Pregnancy symptom set + prediction-UI suppression + end-pregnancy chain
- **Depends on:** p7.2a (the mode + its enablement), p1.5 (symptoms), p1.11 (loss/birth)
- **Acceptance criteria:**
  - A **pregnancy symptom set** — reuse the p1.5 symptom model (a curated built-in name list
    scoped to the mode + the user's own custom symptoms); **no new symptom storage**, logged
    through the existing symptom repo.
  - While pregnancy mode is on, the cycle-prediction card / fertile-window UI on the calendar
    is **hidden** (not deleted — it returns when the mode is turned off).
  - Ending the pregnancy via a p1.11 **loss or birth** turns pregnancy mode off, restores the
    prediction UI, and chains the p7.1 `offerPostpartumMode` path.
  - New `screen_nav.dart` surface(s); sweeps green; dark mode.
- **Tests required:** `app`: pregnancy symptom logging writes through the existing symptom repo;
  prediction UI hidden while active and restored after; end-pregnancy (loss and birth) → mode
  off + postpartum offer shown. Sweeps.
- **Notes / detail:** the week-by-week text is a content asset — keep it terse and get it
  copy-reviewed; **do not import a third-party content pack** (licence + phone-home risk).
  Worker owns the start-reference input shape and the week-note copy.

#### p7.3 — TTC (trying to conceive) mode — daily fertility score + timing guidance
- **Depends on:** p7.1 (mode framework), p1.4 / p3 (`AdaptivePredictor`, fertile window), p1.6
  (BBT / cervical mucus)
- **Requirement refs:** §2 (TTC tools with daily fertility scores), §9(12) (no false precision),
  §1.2 (correctable predictions — never silently overconfident)
- **Goal:** a user trying to conceive sees a **daily fertility score** (a calibrated relative
  likelihood, not a promise) for the current and upcoming days, plus plain timing guidance,
  built from the existing predicted fertile window sharpened by any logged BBT / mucus signals.
- **Acceptance criteria:**
  - Pure `core` `dailyFertilityScore({cycle history, BBT, mucus, day})` → a bounded score with an
    explicit confidence band; **history-aware** (wide/uninformative when the history is thin or
    irregular — no fake precision), clock-injected, deterministic, fully unit-tested. It layers
    on the p3 fertile-window estimate + p1.6 signals; it does **not** introduce a second
    prediction engine.
  - A TTC screen: today's score + the next N days, the current fertile-window estimate as a
    range (never a single "fertile day"), and short non-prescriptive guidance. Honest empty
    state when there isn't enough history.
  - The score is **framed as a relative likelihood from your own patterns**, with the
    not-a-medical-device line and an explicit "this is not contraception guidance" note.
  - Correctable in spirit: the score moves with logged data (a BBT thermal shift, fertile-quality
    mucus) and that linkage is visible to the user.
  - New `screen_nav.dart` surface(s); sweeps green; dark mode; `reduceSpokenDetail` on the
    score if it reads as sensitive.
- **Tests required:** `core` scoring maths — thin history → wide/low-confidence; a clear
  fertile window → elevated score across it with a peak; a logged thermal shift narrows/moves
  it; irregular history stays humble; determinism + clock injection. `app`: screen renders
  score + range + guidance, empty state, the "not contraception" note is present. Sweeps.
- **Notes / detail:** the hard part is calibration honesty, not UI. If backtesting the score
  needs the Phase 3 harness, wire it in; if that balloons the slice, the Worker proposes a
  simpler transparent scoring rule and notes the trade-off (YAGNI — a defensible simple score
  beats an overfit one).

#### p7.4 — PCOS mode — symptom-correlation views, irregular-cycle-aware UI
- **Depends on:** p7.1 (mode framework + correlation-chart widget), p1.5 (symptoms), p1.3
  (`deriveCycles`, gap handling)
- **Requirement refs:** §2 (PCOS symptom-correlation views), §9(2) (irregular-cycle handling),
  §9(12)
- **Goal:** a user with (or investigating) PCOS gets a UI that expects irregular cycles rather
  than flagging them as errors, and correlation views showing how their logged symptoms relate
  to cycle phase / cycle length over time.
- **Acceptance criteria:**
  - Pure `core` correlation derivation: given symptom entries + derived cycles over a range,
    produce a **descriptive** summary per symptom — frequency, and distribution across cycle
    phase (menstrual / follicular / ovulatory / luteal, reusing p1.12's `cyclePhase`) — with an
    honest "not enough data" below a threshold. No p-values, no causal language, no "diagnosis".
  - PCOS mode adjusts the cycle UI: long / variable cycles are shown as **expected in this
    mode**, the likely-gap flag copy softens, predictions carry a wider-interval note. No change
    to the underlying `deriveCycles` / predictor logic — presentation only.
  - Correlation views use the p7.1 shared chart widget (or land it here if p7.1 deferred it).
  - Standard disclaimer; explicitly not a symptom-checker verdict (contrast with Flo's "ask
    your doctor about PCOS" anti-pattern, §9(12)).
  - New `screen_nav.dart` surface(s); sweeps green; dark mode.
- **Tests required:** `core` correlation maths — even distribution → "no clear pattern"; a
  symptom concentrated in one phase → that phase named, descriptively; sub-threshold history →
  "not enough data"; determinism + clock injection. `app`: PCOS-mode cycle UI softening, the
  correlation view renders, empty state, disclaimer present. Sweeps.
- **Notes / detail:** this row also delivers the reusable **cycle-phase correlation** core
  function that p7.5–p7.7 extend (flare↔phase, PMDD rating↔luteal, perimenopause symptom
  timeline). Build it generic here; the later modes parameterise it.

#### p7.5 — Endometriosis mode — pain mapping, flare tracking, cycle-phase correlation
- **Depends on:** p7.1 (framework), p7.4 (correlation core), p1.5 (symptoms)
- **Requirement refs:** §2 (endometriosis symptom-correlation), §9(12), §6
- **Goal:** a user tracking endometriosis can log pain (location + intensity) and flares, and
  see how flares track cycle phase.

**Storage model — decided at negotiation (2026-09-06, worker: 1, PR #80). Orchestrator
approved a dedicated table (schema v7→v8).** The Worker showed the p1.5 presence-only
`(date, symptomTypeId)` model structurally can't carry the three things this log needs — an
*ordered* intensity scale (synthetic catalogue names aren't rankable and break on
rename/archive; they also multiply with the region tag and would leave p7.6 without a real
reusable scale), a free-text note (no text column near the symptom log; dropping the note
criterion is itself a §5 stop), and a region tag. New DDL, shipped **in PR #80** on the p6.1
precedent: additive `pain_entries` table (PK `date`, one row/day: `intensity`
non-null · `region` nullable · `note` nullable TEXT · `isFlare` bool · `createdAt`/`updatedAt`),
`schemaVersion` 7→8 with `if (from < 8) m.createTable(painEntries)`, regen `.g.dart` +
`drift_schemas/v8` + `test/db/generated/schema_v8`, `migration_matrix_test` extended to 8,
new `pain_migration_test.dart`, backup round-trip, `backup_service` `tableOrder` += `pain_entries`
(appended last, no FK). New pure `core` `enum SymptomSeverity` (`.rank` + `.label`) — the
reusable ordered scale; **p7.6 rates its items on this same enum**. `region` is a fixed `core`
`enum PainRegion`, not user-editable. Threat-model p7.5 entry names the new asset (structured
pain/flare rows + free-text pain notes, new local `pain_entries`, SQLCipher-encrypted at rest,
no new egress/permission/CI gate); `docs/release-checklist.md` "Schema change" block updated.
- **Acceptance criteria:**
  - A **pain / flare log**: intensity (an ordered scale) + optional body-region tag + optional
    note, per day — stored in the new `pain_entries` table (see the storage-model block above),
    **not** the p1.5 symptom model.
  - Flare↔cycle-phase correlation via the p7.4 core function ("logged flares cluster in your
    late luteal / menstrual phase" — descriptive only).
  - A simple pain-over-time view (reuses the p7.1 chart widget) with cycle-phase banding.
  - Standard disclaimer; descriptive, non-diagnostic copy.
  - New `screen_nav.dart` surface(s); sweeps green; dark mode; `reduceSpokenDetail` on pain
    detail.
- **Tests required:** `core` — the correlation over flare entries; the severity-scale value
  object if one is added; determinism. If a table is added: the full migration test set. `app`:
  pain logging round-trips, the correlation + timeline views render, empty state, disclaimer.
  Sweeps.
- **Notes / detail:** the severity scale here (ordered pain intensity) is the first ordered
  symptom scale in olf — if it's added to `core`, shape it so PMDD (p7.6) can reuse it rather
  than inventing a second scale.

#### p7.6 — PMDD mode — daily luteal-phase symptom rating + cycle-overlay charts
- **Depends on:** p7.1 (framework), p7.4 (correlation core), p7.5 (ordered severity scale, if
  added there), p1.12 (`cyclePhase`)
- **Requirement refs:** §2 (PMDD daily symptom rating, luteal-phase correlation, cycle-overlay
  charts), §9(12), §6
- **Goal:** a user tracking PMDD can do a quick **daily rating** of a small set of
  mood/physical symptoms and see those ratings overlaid on cycle phase across several cycles —
  the pattern PMDD is defined by (luteal-phase symptom rise, follicular relief).

**Storage model — decided at negotiation (2026-09-06, worker: 2, PR #82). Orchestrator
approved a dedicated table (schema v8→v9).** A daily multi-symptom rating is a
`(date, item, rating)` series — it fits neither p7.5's `pain_entries` (one row per day, a
single intensity) nor the p1.5 presence-only `(date, symptomTypeId)` model. **Rejected**
ALTER-ing `daily_symptom_entries` to add a nullable `severity`: a "rated none today" row would
break the "a row means the symptom happened" invariant that the calendar dots, the
recent-symptoms list and the doctor report all rely on, and would fold PMDD's every-day
ratings into a table many surfaces read. **Approved** option (b) — a new additive
`pmdd_ratings` table (PK `{date, item}`, one row per rated item per day: `item`
`textEnum<PmddSymptom>` — a fixed `core` enum, v1 has no user-configurable rating set ·
`rating` `textEnum<SymptomSeverity>` reusing the p7.5 scale verbatim, and here
`SymptomSeverity.none` **is** a stored value, meaning "rated, nothing today" · `createdAt` /
`updatedAt`). `schemaVersion` 8→9 with `if (from < 9) m.createTable(pmddRatings)` — plain
additive `createTable`, no `to >=` guard (an extra *table* is tolerated at every intermediate
matrix target; only the v7 *column* add needed the guard). Shipped **in PR #82** on the
p6.1 + p7.5 precedent: regen `app_database.g.dart` + real `drift_dev schema dump`
→ `drift_schemas/drift_schema_v9.json` + `test/db/generated/schema_v9.dart`,
`dump_historical_schemas.dart` `_dumpedVersions` += 9, `migration_matrix_test` extended to v9
(from-loops + single-step loop reach 8; `pmdd_ratings` asserted present-and-empty from every
earlier version + usable through its repository), new `pmdd_migration_test.dart`, backup
round-trip carrying a real rated row across the migration, `backup_service` `tableOrder` +=
`pmdd_ratings` (appended last, no FK), `retention_service` `deleteWhere` += `pmdd_ratings`
(ages out on the retention window like every dated table), `docs/local-database.md` "Schema v9"
section. Threat-model p7.6 entry names the new asset (structured PMDD rating rows in a new
local `pmdd_ratings` table, SQLCipher-encrypted at rest, recomputed overlay never stored, no
new egress/permission/CI gate).
- **Acceptance criteria:**
  - A daily **multi-symptom rating** entry — a handful of fixed items (a small hard-coded
    `core` list; v1 has no user-configurable rating scales — noted as a follow-up), each on
    p7.5's `SymptomSeverity` scale, stored in the new `pmdd_ratings` table (see the
    storage-model block above), **not** the p1.5 symptom model. Quick to complete (≤ the p5.5
    tap discipline where the shape allows).
  - A **cycle-overlay chart**: ratings for the current + recent cycles aligned by cycle day /
    phase, so a luteal rise is visible. Uses the p7.1 chart widget.
  - A descriptive luteal-vs-follicular summary via the p7.4 correlation core ("your ratings run
    higher in the luteal phase") — **no DRSP score, no diagnostic threshold, no "you have
    PMDD"**. Disclaimer present.
  - New `screen_nav.dart` surface(s); sweeps green; dark mode; `reduceSpokenDetail` on the
    ratings.
- **Tests required:** `core` — the overlay alignment maths (ratings bucketed by cycle
  day/phase across N cycles; a short/absent cycle handled); the luteal-vs-follicular summary;
  determinism + clock injection. `app`: the daily rating entry, the overlay chart renders with
  seeded multi-cycle data, empty/one-cycle states, disclaimer. Sweeps.
- **Notes / detail:** keep the rating set small and fixed for v1 (YAGNI — no user-configurable
  rating scales yet; note it as a follow-up). The value is the overlay, not a big form.

#### p7.7 — Perimenopause / menopause mode — variability view, symptom timeline, score
- **Depends on:** p7.1 (framework), p7.4 (correlation core), p1.3 (`CycleStats` variability)
- **Requirement refs:** §2 (perimenopause/menopause mode; "Perimenopause Score", "Menopause
  Timeline"), §9(2), §9(12), §6
- **Goal:** a user in the perimenopause transition sees a view built around **increasing cycle
  variability and skipped cycles as the expected signal**, a timeline of perimenopause-relevant
  symptoms (hot flashes, sleep, mood, cycle changes), and a plain-language "where you might be
  in the transition" read.
- **Acceptance criteria:**
  - Pure `core` derivation over cycle history: a **variability trend** (is cycle-length spread
    and skip frequency increasing over the last N months?) and a **descriptive transition
    read** — e.g. "cycles becoming less regular" / "long gaps between cycles" / "12+ months
    since last period" — built from existing `CycleStats` + gap logic, clock-injected. A
    coarse, honestly-hedged "stage" label at most; **not** a numeric medical score, and it says
    so.
  - A perimenopause **symptom timeline** (reuses p7.1 chart / p7.4 correlation) for the
    relevant symptom set (built-in list + custom).
  - The mode reframes long/absent cycles as expected (like PCOS mode p7.4) and widens or
    suppresses forward predictions past a gap rather than asserting them.
  - "12 months without a period" is surfaced factually (the common definition of menopause)
    with the disclaimer — as information, not a diagnosis.
  - New `screen_nav.dart` surface(s); sweeps green; dark mode.
- **Tests required:** `core` — variability-trend maths (stable history → "no clear change";
  widening spread → "becoming less regular"; long gaps → "long gaps between cycles"; 12+ months
  → that surfaced; clock injected, deterministic). `app`: the mode view, the timeline, the
  reframed cycle UI, empty state, disclaimer. Sweeps.
- **Notes / detail:** resist building a real "Perimenopause Score" number — that's the kind of
  false-authority metric §9(12) warns against. A short honest sentence beats a fake 0–100.

#### p7.8 — Birth-control switching support — guided recalibration
- **Depends on:** p7.1 (framework), p1.7 (birth-control method history), p3 (predictor)
- **Requirement refs:** §2 (birth-control-switching support), §1.2 (predictions never silently
  overconfident), §6
- **Goal:** when a user records starting or stopping hormonal contraception (via the p1.7 BC
  method history), olf **acknowledges that cycle data will be disrupted** and guides them
  through a recalibration period instead of showing confident predictions built on
  pre-switch cycles.
- **Acceptance criteria:**
  - A start/stop hormonal-BC event (from the existing p1.7 method history — **check whether p1.7
    records enough**; if it needs one more field that's a schema change → §5 stop + migration in
    the same PR) triggers a **recalibration state**: for a defined window after the switch, the
    prediction card shows a plain "your cycle may be settling after a birth-control change —
    predictions will be less certain for a while" note and widens or withholds the forward
    estimate.
  - A short guided explainer of what to expect (starting vs. stopping; withdrawal bleeds vs.
    true cycles) — bundled, reviewed, disclaimer, no tracked links.
  - The predictor itself is **not** rewritten — this is a presentation/weighting note layered on
    p3's output (mirrors the PCOS/perimenopause reframing). Optionally, exclude clearly
    pre-switch cycles from the estimate for the recalibration window if p3 already supports
    time-scoped exclusion; if not, don't build it — just widen/annotate.
  - Recalibration state clears automatically after the window, or when enough post-switch cycles
    are logged, whichever first. The user can dismiss it early.
  - New `screen_nav.dart` surface(s) or an additive state on the existing prediction surface;
    sweeps green; dark mode.
- **Tests required:** `core` — the recalibration-window logic (in window → annotated/withheld;
  window elapsed → normal; enough post-switch cycles → cleared early; clock injected). `app`:
  BC start/stop → recalibration note appears, explainer renders, auto-clear + manual dismiss,
  prediction restored after. Sweeps.
- **Notes / detail:** smallest Phase 7 slice if p1.7's method history already carries the
  start/stop dates — verify that first. Don't add BC-type-specific pharmacology; the note is
  generic ("a hormonal birth-control change").

**Exit gate (Phase 7) — MET (2026-09-06):** each mode ships independently, opt-in, tested,
non-diagnostic, with correlation / timeline views where the requirement calls for them.
- *Postpartum cycle-return + loss/birth support + the mode framework* — **MET: p7.1 #73
  `4e84c30`** (`LifeStageMode` enum + `app_settings` `mode.<name>` keys, `ModesPage`,
  `mode_offer`, pure `derivePostpartumCycleReturn`, loss-vs-birth support resources).
- *Pregnancy mode: gestational-age core + week view + enable/start-reference flow* — **MET:
  p7.2a #74 `b058299`** (`gestational_age.dart` LMP/dueDate/conception → `lmpAnchor` seam,
  `kPregnancyWeekNotes` wk 0–42, `pregnancy.start_reference` KV — no schema change).
- *Pregnancy mode: pregnancy symptom set + prediction-UI suppression + end-pregnancy →
  postpartum* — **MET: p7.2b #76 `5fb2734`** (`kPregnancySymptomNames` logged through the p1.5
  repo, `_PredictionCard` gated `!pregnancyModeOn`, loss/birth clears the mode then offers
  postpartum). Enablement criterion altered at negotiation — Modes-section-only (Option A),
  the start-reference input doubles as the "I'm pregnant" record; `docs/plan/decisions.md`
  2026-09-06.
- *TTC mode with an honest daily fertility score* — **MET: p7.3 #77 `0553215`**
  (`daily_fertility_score.dart` — a day-relative shape curve on the p3 ovulation estimate,
  re-centred by an observed thermal shift + floored by fertile mucus, `.clamp(1, 99)`, `< 2`
  cycles → null; `thermal_shift.dart` retrospective 3-over-6 detector; **not** a second
  engine; explicit "not contraception guidance" disclaimer).
- *PCOS mode (irregular-cycle-aware UI + symptom correlation) + the reusable correlation core*
  — **MET: p7.4 #79 `276420d`** (`cycle_phase_correlation.dart` `cyclePhaseCorrelations` —
  rate-normalised concentration, no p-values; `cyclePhaseTimeline`; `CorrelationChart` shared
  widget; `pcosMode` copy-softening — presentation only; anti-Flo `pcosNotSymptomCheckerLine`).
- *Endometriosis mode (pain/flare log + cycle-phase correlation)* — **MET: p7.5 #80
  `cf11233`** (schema **v7→v8** — new additive `pain_entries` table + pure `enum
  SymptomSeverity`; `painFlareEvents` → `cyclePhaseCorrelations`; migration + matrix→v8 +
  `pain_migration_test` + backup round-trip in the PR; `docs/plan/decisions.md` 2026-09-06).
- *PMDD mode (daily rating + cycle-overlay chart)* — **MET: p7.6 #82 `25afc44`** (schema
  **v8→v9** — new additive `pmdd_ratings` table, composite `{date, item}` PK, `PmddSymptom`
  fixed enum, `SymptomSeverity` rating with `none` stored; pure `pmddOverlay` reuses
  `cyclePhaseCorrelations` unchanged → `PmddLutealRead` enum, **no DRSP/numeric score**;
  migration + matrix→v9 + `pmdd_migration_test` + backup round-trip in the PR;
  `docs/plan/decisions.md` 2026-09-06).
- *Perimenopause / menopause mode (variability view + symptom timeline)* — **MET: p7.7 #81
  `3d8d788`** (`perimenopause_transition.dart` — `PerimenopauseVariabilityTrend` +
  `PerimenopauseStageHint` enums over `CycleStats` + gap logic, **NO numeric "Perimenopause
  Score"** — content test asserts it; "12 months" surfaced factually; forecast withheld past a
  long gap).
- *Birth-control-switching recalibration support* — **MET: p7.8 #78 `91df394`**
  (`birth_control_recalibration.dart` — `isHormonal` on the p1.7 `BirthControlMethod`, no
  schema change; forecast **withheld** during a 90-day / 3-cycle window, sticky dismissal;
  predictor untouched — `AdaptivePredictor` has no time-scoped exclusion seam).
- *Phase-wide:* every mode opt-in + reversible with no data loss on disable; every derivation
  pure `core` / `DateTime.now()`-free; no diagnostic or alarming language (§9(12)); each mode
  carries the not-a-medical-device line; two schema changes (p7.5 v7→v8, p7.6 v8→v9) each
  shipped with its migration + matrix extension + backup round-trip in the same PR; nothing
  gated behind payment (§5).

**Phase 7 — phase-wide truths (p7.1–p7.8):**
- **Everything free.** The Phase 7 stub's "insights may later be paid" line is dead — every
  mode's logging *and* its correlation/insight/overlay views ship free (§5).
- **`core` stayed Flutter-free / `DateTime.now()`-free.** Every derivation is pure, clock-
  injected Dart in `core`: `derivePostpartumCycleReturn`, `gestationalAgeAsOf`,
  `dailyFertilityScore` + `thermalShift`, `cyclePhaseCorrelations` + `cyclePhaseTimeline`,
  `painFlareEvents`, `pmddOverlay`, `derivePerimenopauseTransition`,
  `deriveBirthControlRecalibration`. Mode *screens* live in `app`; `DateTime.now()` is read
  only at the provider edge.
- **Two schema bumps, both additive, both in their slice's PR.** p7.5 `schemaVersion` **7→8**:
  `pain_entries` (endometriosis pain/flare log, one row/day, free-text note). p7.6 **8→9**:
  `pmdd_ratings` (composite `{date, item}` PK, one row per rated item per day, enum-only).
  Both plain `createTable`, no `to >=` guard (an extra table is tolerated at every
  intermediate `migration_matrix_test` target — only the v7 *column* add needed the guard).
  Each shipped with `migration_matrix_test` extended to the new version, a dedicated
  `*_migration_test.dart`, a real `drift_dev schema dump` (v8, v9 in `_dumpedVersions`), and a
  backup round-trip carrying real rows across the migration. `BackupService.tableOrder` +
  `RetentionService.deleteWhere` cover both new tables. §5 negotiated both times
  (`docs/plan/decisions.md`); the p1.5 presence-only symptom model was shown structurally
  unable to carry an ordered scale / free text / per-item daily ratings.
- **The shared framework, built once in p7.1 + p7.4, reused by the rest.** p7.1: the
  `LifeStageMode` enum, the `app_settings` `mode.<name>` enablement seam, `ModesPage`,
  `mode_offer`. p7.4: `cyclePhaseCorrelations` (the descriptive correlation core — p7.5, p7.6,
  p7.7 all parameterise it unchanged), `cyclePhaseTimeline`, and the `CorrelationChart`
  widget (p7.1-deferred; p7.5–p7.7 reuse it as-is). The `period_calendar_page.dart`
  prediction-card region became a composed gate across pregnancy / bcRecal / perimenopause
  modes with `pcosMode` + `perimenopauseMode` wording flags threaded through the cards and
  `cycle_format.dart` — presentation only, `deriveCycles` / `CycleStats` / predictor never
  touched.
- **Reuse, don't fork — held.** No mode forked the cycle engine or the predictor. The
  predictor stayed behind its unchanged seam; where a mode needed the forecast to back off
  (pregnancy, BC-switch, perimenopause past a gap) the card is **withheld or annotated**, not
  rebuilt.
- **§9(12) — no diagnoses, enforced by tests.** No mode emits a verdict, a directive, or a
  numeric medical score. p7.4 (anti-Flo "ask your doctor about PCOS"), p7.6 (no DRSP / 0–100),
  p7.7 (no "Perimenopause Score") each carry a content test that locks the copy and asserts
  the absence of a score. Every mode screen shows `SupportResources.notMedicalDeviceLine`.
- **Threat model.** Each slice's review-log entry is in `docs/threat-model.md` (p7.3's added
  at close — a derived read, no new asset/egress/schema/permission/CI). Two new encrypted
  local assets (`pain_entries` incl. free-text notes, `pmdd_ratings` enum-only) added to the
  Assets table; both SQLCipher-encrypted at rest, both covered by backup + retention, never
  leaving the device. No new adversary, trust boundary, network path, dependency, permission,
  manifest/plist, or CI gate anywhere in the phase.

**Deferred to backlog (see `backlog.md`):** pregnancy-mode offer from a logged positive-
pregnancy state (needs a `pregnancyStart` `CycleEventType` — a schema change) · `thermalShift`
operating on the reading sequence not calendar-spaced days · endometriosis v1 scope cuts (one
region/day, no retroactive severity on the p1.5 log, plain chips not a body-map, no standalone
pain time-series widget) · PMDD v1 scope cuts (no user-configurable rating items or scale;
"checked in, all fine" not distinct from an all-`none` day).

### Notes — per-slice record (frozen at close)

The live per-slice build log lived in `.herdsman/state.md` during the phase; the merged record:

| Slice | PR | SHA | One-line |
|---|---|---|---|
| p7.1 | #73 | `4e84c30` | Loss/birth/postpartum flows + the mode framework (`LifeStageMode`, `mode.<name>` KV, `ModesPage`, `mode_offer`, `derivePostpartumCycleReturn`, support resources). No schema change. Correlation-chart widget deferred to p7.4. |
| p7.2a | #74 | `b058299` | Pregnancy part 1: `gestational_age.dart` (LMP/dueDate/conception → `lmpAnchor` seam, honest null before anchor), `kPregnancyWeekNotes` wk 0–42, `pregnancy.start_reference` KV. No schema change. |
| p7.2b | #76 | `5fb2734` | Pregnancy part 2 (app-only): `kPregnancySymptomNames` via the p1.5 repo, `_PredictionCard` gated `!pregnancyModeOn`, loss/birth → clear mode → offer postpartum. Enablement criterion altered (Option A) at negotiation. |
| p7.3 | #77 | `0553215` | TTC mode: `daily_fertility_score.dart` (day-relative curve on the p3 estimate, re-centred by `thermalShift`, floored by fertile mucus, clamp 1–99, `<2` cycles → null) + `thermal_shift.dart`. Not a second engine. `// SHORTCUT`: shift detector walks the reading sequence, not calendar days (backlog). No schema change. Threat-model entry added at close. |
| p7.4 | #79 | `276420d` | PCOS mode + the reusable correlation core: `cyclePhaseCorrelations` (rate-normalised concentration, no p-values, `today` injected), `cyclePhaseTimeline`, `CorrelationChart` widget, `pcosMode` copy-softening (presentation only). No schema change. |
| p7.5 | #80 | `cf11233` | Endometriosis mode + **schema v7→v8**: new additive `pain_entries` table (PK `date`, `SymptomSeverity` intensity + `PainRegion` + free-text note + flare flag) + pure `enum SymptomSeverity`. `painFlareEvents` → `cyclePhaseCorrelations`. Migration + matrix→v8 + `pain_migration_test` + backup round-trip + `drift_schema_v8` in the PR. §5 negotiated. |
| p7.6 | #82 | `25afc44` | PMDD mode + **schema v8→v9**: new additive `pmdd_ratings` table (composite `{date, item}` PK, `PmddSymptom` fixed enum, `SymptomSeverity` rating with `none` stored). Pure `pmddOverlay` reuses `cyclePhaseCorrelations` unchanged → `PmddLutealRead` enum. **No DRSP/numeric score** (content test). Migration + matrix→v9 + `pmdd_migration_test` + backup round-trip + `drift_schema_v9` in the PR. §5 negotiated. `modeHasScreen` made exhaustive. |
| p7.7 | #81 | `3d8d788` | Perimenopause mode: `perimenopause_transition.dart` — `PerimenopauseVariabilityTrend` + `PerimenopauseStageHint` enums over `CycleStats` + gap logic; **NO numeric score** (content test); "12 months" factual; forecast withheld past a long gap; symptom timeline reuses `cyclePhaseCorrelations`. No schema change. |
| p7.8 | #78 | `91df394` | Birth-control-switching recalibration: `birth_control_recalibration.dart` — `isHormonal` on the p1.7 `BirthControlMethod` (no schema change — §5 pre-check cleared); forecast **withheld** during a 90-day / 3-cycle window, dismissal sticky until a newer switch; predictor untouched. |
| close | #… | `…` | Exit gate, `overview.md` row 7 → DONE, `architecture.md` refresh, p7.3 threat-model entry, this frozen record; carries the batched local-`main` bookkeeping stack. |

---
