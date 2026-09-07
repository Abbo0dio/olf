### Phase 8 — Passive wearable integration

**Requirement refs:** §2 (BBT manual *and via wearable*; wearable integration — Natural
Cycles/Clue sync Oura, Apple Watch, Garmin, WHOOP, Fitbit for passive overnight temperature
capture; "the single biggest UX friction-reducer in the category"), §10 (passive
temperature + HRV + sleep predicting cycle phase — research shows ~87% accuracy from skin
temperature + HRV; friction toward zero), §9 (robust wearable sync; no data loss on
OS-update/migration), §5 (**free** — wearable sync is never paywalled; explicitly contra
Clue locking Oura/Fitbit/WHOOP behind Clue Plus and Flo/Clue's retroactive-paywall
complaint pattern), §6 (not a medical device — passive inference is a correctable estimate,
never a diagnostic claim).

**What this phase is.** olf already imports temperature/flow from Apple Health and Health
Connect behind a swappable `core` seam (Phase 6): `HealthPlatformGateway` +
`FakeHealthPlatformGateway`, the pure `ImportReconciler` (never dupes, never clobbers a
`source == manual` row), the hand-rolled `olf/health` `MethodChannel`, and `source` /
`external_id` provenance columns on `daily_flows` + `bbt_entries` (schema v7). The p6.1 model
already **declares** `HealthSampleType.wristTemperature` and `HealthSampleType.sleep` — iOS
currently no-ops them.

Phase 8 lights those up: pull **passive overnight wrist-temperature** (and, where useful, HRV
and sleep) from the wearables users already own, feed it into the existing storage + the
Phase 3 predictor, and add a **passive cycle-phase inference** that reduces manual logging
toward zero while staying fully correctable. The Apple Watch path and at least one
third-party wearable must reach production; the inference must be measured against the
Phase 3 backtester.

**Phase-wide constraints.**
- **Free.** Every wearable connection and every passive-inference view ships free (§5). No
  source is gated, no "connect your Oura" upsell. The Phase 8 stub predates the free-forever
  decision — nothing here is paid.
- **Reuse the Phase 6 seam, don't fork it.** New sources are new `HealthPlatformGateway`
  implementations and/or new `HealthSampleType` mappings feeding the **same**
  `ImportReconciler`, the same `source` / `external_id` provenance model, the same
  purge-before-sync retention path, the same `conflict_review_screen`. A source that needs a
  genuinely new ingestion shape flags it at negotiation.
- **`core` stays Flutter-free / `DateTime.now()`-free.** The passive cycle-phase inference,
  the multi-source precedence rules, and any signal-quality maths live in `core` as pure,
  clock-injected Dart. Platform bridges (Swift/Kotlin), OAuth flows, and the watch companion
  live in `app` / native targets.
- **Opt-in, default-off, per source; disabling loses no data.** Each wearable is connected
  from one place (the existing "Apps & export" Settings section), off until the user connects
  it, and disconnecting keeps every imported reading (`source` provenance is retained). No
  passive feature changes the default home/calendar for a user who has connected nothing.
- **Device-level provenance is additive.** olf currently records `source ∈ {manual,
  appleHealth, healthConnect}`. Naming the *device* behind a platform sample ("from your Oura
  Ring", "from Apple Watch") needs more than that enum — a nullable `source_device` text
  column / free-form tag over a closed enum, added as a **schema change**. It lands in **p8.2**
  (where multiple devices coexist), not p8.1a — p8.1a distinguishes passive-vs-typed with the
  `measurement_kind` column alone (negotiation 2026-09-06). Every schema change ships with its
  migration + `migration_matrix_test` extension + a dedicated `*_migration_test.dart` + a
  backup round-trip in the same PR (the p6.1 / p7.5 / p7.6 precedent;
  `docs/release-checklist.md` "Schema change" block). `schemaVersion` is **9** after Phase 7 —
  p8.1a takes it to **10** (`measurement_kind` on `bbt_entries`), p8.2 to **11**
  (`source_device` on `daily_flows` + `bbt_entries`).
- **A direct cloud API is a §5 conversation, per wearable.** The default path is *via the
  health platform* (Apple Health / Health Connect) — no new dependency, no network. A
  vendor's own cloud API (Oura Cloud, WHOOP, Garmin Health) brings an **OAuth
  client-credential**, **outbound network egress** (the first real use of the
  `OlfHttpClient` TLS chokepoint from p2.6), and a **threat-model event**: Worker stops,
  Orchestrator rules. No wearable SDK is added without a `dependency-audit` pass (no
  ad/analytics/telemetry, GPLv3-compatible licence).
- **New native targets are a §5 conversation.** A watchOS companion app is a new Xcode
  target with its own HealthKit entitlement + usage strings and its own CI build coverage —
  three negotiation triggers. It is sequenced *after* the data path it depends on is proven.
- **Passive inference stays behind the unchanged Phase 3 seam and stays correctable.** The
  inference is an input to / annotation on `AdaptivePredictor`, never a replacement; the
  `Predictor` interface does not change. Every passively-derived phase is visibly
  correctable through the existing quick-log flow (p1.12 precedent). It is measured against
  the Phase 3 backtester and must not regress MAE or calibration on the seeded profiles.
- **Slices are mostly independent.** p8.1a is sequenced first (it lights up the
  `wristTemperature` path the rest lean on). p8.5 (inference) depends on real multi-signal
  data existing, so it follows the source slices. p8.6 (multi-source arbitration) hardens
  what the source slices produce.

---

#### p8.1a — Apple Watch passive wrist-temperature path (data path only, no companion app)
- **Depends on:** p6.1 (`HealthSample` model, `ImportReconciler`, provenance columns), p6.2
  (the `olf/health` HealthKit bridge, `NSHealth*UsageDescription`, `com.apple.developer.healthkit`
  entitlement), p1.6 (`bbt_entries`).
- **Requirement refs:** §2 (BBT via wearable; Apple Watch wrist temperature), §10 (passive
  temperature), §9 (robust sync).
- **Goal:** an Apple Watch (Series 8+ / Ultra) that captures overnight *sleeping wrist
  temperature* to Apple Health has that reading flow into olf automatically — reconciled,
  provenance-tagged, retention-bounded, visible, and correctable — with **no new watch app**
  and **no new dependency**.
- **Acceptance criteria:**
  - The HealthKit bridge reads `HKQuantityTypeIdentifier.appleSleepingWristTemperature`
    (add it to the HealthKit read-authorization request; existing usage strings cover it),
    mapped to the already-declared `HealthSampleType.wristTemperature` (°C). **HRV / sleep are
    NOT mapped in this slice** (negotiation 2026-09-06): HRV needs a new `HealthSampleType` +
    a new `HealthUnit(ms)` + `_unitMatchesType`, sleep needs an interval-aggregation query
    path — neither is a small extension. Both stay declared-but-unmapped; **p8.5 owns them.**
  - **Storage decision — RESOLVED at negotiation (2026-09-06, worker: 1, PR #84). Orchestrator
    approved option (a): a `measurement_kind` discriminator column on `bbt_entries`;
    `schemaVersion` 9→10.** A dedicated `wrist_temperature` table (option b) was **rejected** —
    the reconciler matches by `(type, day)`, so a separate table makes a wrist import and a
    manual BBT day independent, and the "unchanged `ImportReconciler` conflicts a wrist import
    against a manual BBT day" criterion becomes impossible without touching the reconciler.
    Plain reuse (option c) was **rejected** — an unmarked `tempCelsius` conflates sleeping-wrist
    with basal-body: `thermalShift`, the BBT chart, and the doctor PDF would silently mix
    semantics and the UI can't show passive vs typed distinctly. Approved: `measurement_kind`
    `TEXT NOT NULL DEFAULT 'basal'` (`enum BbtMeasurementKind { basal, sleepingWrist }`),
    `textEnum` in drift. `HealthImportService` reads the bridge value as
    `HealthSampleType.wristTemperature`, re-types it to `basalBodyTemperature` **only** for the
    `reconcile()` `(type, day)` match so it competes for the one temperature slot per day
    through the unchanged reconciler, and stamps `measurementKind: sleepingWrist` on `apply`.
    A code comment at the re-type site must state why.
  - **Existing `bbt_entries` temperature readers filter to `measurement_kind = 'basal'`
    (negotiation condition).** Audit every consumer — `thermalShift` (p7.3), `dailyFertilityScore`
    (p7.3), `ClinicalReport` / doctor PDF (p6.5), the p1.6 BBT chart / any `CycleStats` BBT
    use — and make each read `basal`-only (or deliberately handle both kinds, documented) so
    p8.1a introduces **zero behaviour change** to existing features. A `sleepingWrist` row must
    never silently alter a thermal-shift result, a fertility score, or a doctor-PDF chart.
    `p8.5` is where sleeping-wrist deliberately feeds inference.
  - **No `source_device` column in p8.1a** (negotiation 2026-09-06). `measurement_kind ==
    sleepingWrist` + `source == appleHealth` already uniquely means "passively captured by an
    Apple Watch" (on iOS today, nothing else writes `appleSleepingWristTemperature`) — enough
    for the "passive vs typed distinctly" criterion. Free-form multi-device attribution
    (`source_device`) earns its keep in **p8.2** when Oura / Garmin coexist; added there.
  - Reconciliation is the existing `ImportReconciler` unchanged: a manual BBT entry for a day
    is never overwritten by a wrist-temperature import (it becomes a reviewable conflict); a
    prior wrist-temperature import for the same day updates in place via `external_id`; a
    same-day existing `appleHealth` basal reading is a deterministic same-source update.
  - **Surface:** the BBT / temperature view shows passively-captured readings distinctly from
    typed ones ("Apple Watch · captured while you slept"), and every passive reading is
    editable / correctable / deletable through the existing flow. A per-source status line in
    the "Apps & export" section (connected · last sync · count), `reduceSpokenDetail`-redacted.
  - Retention (p2.3) ages out wrist-temperature readings on the same window as every dated
    table; backup/restore round-trips them. `bbt_entries` is **already** in
    `BackupService.tableOrder` + `RetentionService.deleteWhere` — wrist rows age out /
    round-trip automatically, no additions needed.
  - **Migration deliverable (in PR #84):** `schemaVersion` 9→10;
    `if (from < 10 && to >= 10) { if (from >= 5) m.addColumn(bbtEntries, bbtEntries.measurementKind); }`
    (the p6.1 v7 column-add precedent — `to >=` guard because it's an ALTER, inner `from >= 5`
    because `bbt_entries` was created at v5); regen `app_database.g.dart` + real `drift_dev
    schema dump` → `drift_schemas/drift_schema_v10.json` + `test/db/generated/schema_v10.dart`;
    `dump_historical_schemas.dart` `_dumpedVersions` += 10; `migration_matrix_test` → v10
    (asserts `measurement_kind == 'basal'` on every pre-existing row + a backup round-trip
    carrying a `sleepingWrist` row across the migration); new `wrist_temp_migration_test.dart`
    (hand-rolled v9 on disk → v10, `PRAGMA table_info` shape check). `docs/local-database.md`
    "Schema v10" section + `from < 10` row; `docs/release-checklist.md` "Schema change" block
    already covers the steps.
  - `docs/threat-model.md`: review-log entry — new asset (passive sleeping-wrist temperature
    readings, tagged `measurement_kind`) in the existing encrypted local DB; **no new egress**
    (data arrives over the existing local HealthKit IPC), no new permission (same HealthKit
    entitlement), no new dependency.
  - New `screen_nav.dart` surface(s) for any new/changed screen; five a11y sweeps green; dark
    mode; `reduceSpokenDetail` on temperatures.
- **Tests required:** `core` — `wristTemperature` sample round-trips the model °C invariant;
  `ImportReconciler` (unchanged) treats a re-typed wrist import against a manual BBT day as a
  conflict, against a prior wrist import for the day as an in-place `external_id` update, and
  against a same-day `appleHealth` basal reading as a deterministic same-source update;
  `thermalShift` / `dailyFertilityScore` / `buildClinicalReport` ignore `sleepingWrist` rows
  (a mixed-kind history produces the identical result to a `basal`-only history). Schema:
  `migration_matrix_test` → v10 + `wrist_temp_migration_test.dart` (v9 on disk → v10) +
  backup round-trip with a `sleepingWrist` row. `app` — the HealthKit channel wrapper decodes
  a sleeping-wrist payload (mocked platform channel); the import service applies inserts +
  skips conflicts + stamps `measurementKind: sleepingWrist`; the temperature view renders
  passive vs manual distinctly and a passive reading is correctable; per-source status line;
  sweeps.
- **Notes / detail:** hand-rolled bridge only — **no `health` package** (p6.2 rejected it;
  no `BASAL_BODY_TEMPERATURE`/wrist-temp coverage and it forces an SDK-floor bump). The Swift
  side is a thin addition to the existing `HealthKitBridge`. Real Apple Watch capture is a
  p0.5 device-smoke item (no watch hardware in CI). Keep HRV/sleep minimal here; p8.5 is
  where they earn their place.

#### p8.1b — Apple Watch companion app (SwiftUI) — glanceable cycle view + complication
- **Status: DEFERRED to backlog (2026-09-07, Phase 8 close).** Conditional slice — the exit
  gate ships it only "if its §5 plumbing (new target + entitlement + CI) clears". The four
  hard exit-gate requirements are met without it; a watchOS target is a standalone
  capability-surface addition (new Xcode target, its own HealthKit entitlement, a CI compile
  lane) better scoped as its own focused effort than as phase-tail work, and it delivers a
  glanceable *mirror* of on-device data, not a capability gap. See `backlog.md`.
- **Depends on:** p8.1a (the data path + provenance it establishes), p1.12 (`currentCyclePhase`).
- **Requirement refs:** §2 (Apple Watch companion), §10.
- **Goal:** a minimal watchOS companion — a glanceable current-cycle-phase view and a
  watch-face complication — reading olf's data on the wrist. **No new data collection**
  beyond what p8.1a established; the watch is a read/quick-glance surface, not a second
  logging engine.
- **Acceptance criteria:**
  - A new **watchOS app target** in the Xcode project (SwiftUI), its own bundle id under the
    existing app id, its own HealthKit entitlement + usage strings, paired to the iOS app.
    **This is a §5 stop before any of it is built** (new target + new capability surface +
    CI build coverage for the target).
  - The watch app shows the current cycle phase + day (mirroring p1.12's `currentCyclePhase`
    read) and the last passive temperature; an honest empty/placeholder state when there is
    no cycle data. Data crosses from phone to watch via a shared App Group / `WatchConnectivity`
    — **no cycle data leaves the device**, no network.
  - At least one **complication** (corner / circular) showing the phase at a glance,
    respecting the discreet-mode spirit (no overt "period" text on a face others may see —
    reuse the p5.3 `reduceSpokenDetail` posture / p5.4 discreet framing).
  - CI: the watchOS target builds in the iOS build job (or a documented added step). No
    signing in CI (same posture as the iOS app) — compile validation only. **CI-workflow
    change = §5 stop.**
  - `docs/threat-model.md`: review-log entry — new surface (watch), new on-device transport
    (App Group / `WatchConnectivity`), no new egress, no new asset class. Data-flow diagram
    updated for the phone↔watch arrow.
- **Tests required:** the iOS↔watch payload codec is pure and unit-tested (phase + day +
  temperature ↔ wire form, empty state). Swift UI is thin — CI build validates compile; real
  paired-device behaviour is a p0.5 smoke item. No Flutter widget tests (the surface is
  native).
- **Notes / detail:** deliberately tiny. Complication art / final visual polish is a design
  follow-up (p5.4 icons precedent). If the target + entitlement + CI plumbing alone fills a
  reviewable PR, the glance view and the complication may split again at negotiation.

#### p8.2 — Third-party wearables via the health platform + device provenance (Oura, Garmin)
- **Depends on:** p8.1a (the `wristTemperature` ingestion path + the `measurement_kind`
  column), p6.3 (Health Connect bridge, for the Android side).
- **Requirement refs:** §2 (Oura, Garmin), §10, §9 (robust sync), §5 (free — not paywalled).
- **Goal:** a user whose Oura Ring or Garmin device already syncs to Apple Health / Health
  Connect sees that temperature (+ HRV / sleep) in olf, **labelled by device** ("from your
  Oura Ring"), through the same import path — **no vendor SDK, no OAuth, no network**.
- **Acceptance criteria:**
  - The import path reads the same `HealthSampleType`s regardless of which device wrote them;
    **this slice adds the nullable `source_device` text column** to `daily_flows` +
    `bbt_entries` (schema change — **pre-authorised at Phase 8 planning**, see the
    "Device-level provenance is additive" phase-wide constraint; not a fresh §5 stop.
    `schemaVersion` **10 → 11**; full migration deliverable in the PR per the p8.1a v9→v10
    `measurement_kind` precedent). Migration:
    `if (from < 11 && to >= 11) { if (from >= 3) m.addColumn(dailyFlows, dailyFlows.sourceDevice); if (from >= 5) m.addColumn(bbtEntries, bbtEntries.sourceDevice); }`
    — `daily_flows` was created at **v3**, `bbt_entries` at **v5** (the v7 per-table inner-guard
    precedent). Populated from the platform sample's `HKSource` / `HKDevice` (iOS) or the Health
    Connect origin / data-origin package (Android) so olf can attribute a reading to Oura /
    Garmin / Apple Watch / another app.
  - A per-device status surface in "Apps & export": which devices have contributed data, last
    sync, counts — `reduceSpokenDetail`-redacted. Disconnecting olf from the platform keeps
    the readings; there is no per-device "connect" beyond the platform grant.
  - Reconciliation across devices is deterministic and **loses no reading**. p8.6 defines the
    precedence order; this slice must not dupe and must not clobber — two devices reporting the
    same day is one reconciled reading when they agree (within `tolerance`) and a **reviewable
    conflict** (existing `conflict_review_screen`) when they disagree materially.
    - **§5 ruling (2026-09-07, p8.2 negotiation, worker: 1):** the p6.1 `ImportReconciler`
      as-shipped cannot meet this — two devices on one platform both arrive `source =
      appleHealth`, so `crossSourceDisagreement` (gated on `match.source != sample.source`)
      never fires, and a not-yet-inserted `(type, day)` collision isn't detected at all
      (`byTypeDay` is built from local rows only) → the second reading is silently lost via
      last-writer upsert. **Approved: one minimal additive reconciler clause**, not a fork:
      (1) thread the nullable `sourceDevice` through `HealthSample` + `LocalSampleView`
      (the column this slice adds anyway); (2) register `inserts` into `byTypeDay` as they
      accumulate so a second incoming for the same fresh `(type, day)` is matched;
      (3) new `ConflictReason.crossDeviceDisagreement` when the `(type, day)` match is
      **same `source`, different non-null `sourceDevice`, values disagree beyond `tolerance`**.
      `externalId` match still wins first; agreement within `tolerance` still skips regardless
      of device; same-`sourceDevice` (or both-null) intra-batch disagreement stays a
      deterministic last-by-`_stableOrder` update, **not** a conflict (a device revising
      itself, or unattributable legacy rows — no conflict the user could resolve).
      **No precedence / arbitration here** — the user resolves; p8.6 owns the precedence
      policy and sits on top of a reconciler that now *detects* cross-device disagreement.
      **Single-source behaviour is byte-for-byte unchanged and regression-locked** by the
      existing reconciler suite plus an explicit "single source, any input order → identical
      plan" test.
  - No new dependency, no new permission beyond the existing HealthKit / `health.*` grants,
    no network. `docs/threat-model.md` review-log entry — provenance is now finer-grained,
    still the same asset class + same local IPC, no new egress.
  - `docs/health-platform-interop.md` updated with the device-attribution behaviour and the
    iOS-vs-Android capability asymmetry for third-party device metadata.
- **Tests required:** `core` — device tag flows from a raw sample through
  `healthSampleFromRaw` into storage and back; a two-device same-day **disagreement** is a
  `crossDeviceDisagreement` conflict (both as a fresh-day intra-batch collision and against an
  existing local row), a two-device **agreement** is one reading; a device **revising itself**
  in one batch (same `sourceDevice`) is a deterministic update, not a conflict; **single
  source, any input order → identical `ReconciliationPlan`** (regression lock); `externalId`
  match still pre-empts `(type, day)`. Schema: `migration_matrix_test` → v11 (all three loops;
  `source_device` NULL on every pre-existing row) + `source_device_migration_test.dart`
  (hand-rolled v10 on disk → v11, `PRAGMA table_info` on both tables) + a backup round-trip
  carrying a non-null `source_device`. `app` — status surface lists contributing devices from
  mocked platform payloads; Oura-style and Garmin-style payloads both decode with their device
  tags; the channel wrapper decodes `HKSource`/`HKDevice` metadata. Sweeps for the changed
  screen.
- **Notes / detail:** Garmin's direct **Garmin Health API** is a server-to-server partnership
  program, not a simple OAuth app — explicitly **out of scope** here; the platform path is
  the supported route. Oura *also* has a cloud API (p8.3) — this slice is the zero-dependency
  path that covers most real users. This slice can satisfy the exit gate's "at least one
  third-party wearable in production" on its own.

#### p8.3 — Direct wearable cloud API (the §5-heavy path) — Oura Cloud and/or WHOOP
- **Status: DEFERRED to backlog (2026-09-07, Phase 8 close).** The exit gate explicitly
  permits this: "the direct cloud API (p8.3) ships **or is recorded as a backlog deferral**".
  p8.2 already satisfies the "≥1 third-party wearable" clause, and this slice is the single
  largest security-surface change in the project so far — `OlfHttpClient`'s first real
  outbound egress, an OAuth2 client, a `flutter_secure_storage` token store, a threat-model
  new-boundary entry. WHOOP-only users are the sole cohort not covered by the platform path.
  Deferred so it can be designed and reviewed as dedicated work. See `backlog.md`.
- **Depends on:** p8.2 (platform-path provenance model), p2.6 (`OlfHttpClient` TLS chokepoint).
- **Requirement refs:** §2 (WHOOP; Oura), §10, §3 (privacy — no third-party data sharing),
  §6.
- **Goal:** for a wearable that does **not** reliably write to a health platform (WHOOP
  writes almost nothing to Apple Health / Health Connect; Oura Cloud gives richer data than
  the platform export), an opt-in direct connection over the vendor's OAuth2 cloud API.
- **Acceptance criteria — every one of these is a negotiation point, resolve before code:**
  - **§5 STOP up front.** This slice adds: an **OAuth2 client** (client id/secret handling —
    where do they live? a build-time config, not committed), **outbound HTTPS** to a vendor
    host (the first real use of `OlfHttpClient` — pin / verify per p2.6), a **token store**
    (`flutter_secure_storage`, like the DB key), and a **threat-model event** (a new trust
    boundary, a new egress, a third party now sees a token but — critically — olf sends them
    *nothing* about the user's cycle). Orchestrator rules on scope, on which vendor(s), and
    on whether this ships in Phase 8 at all or defers to backlog.
  - If approved: opt-in from "Apps & export", explicit consent naming exactly what olf will
    **fetch** (temperature, HRV, sleep) and stating olf **uploads nothing**; a revoke that
    deletes the stored token; imported readings tagged `source_device` = the vendor, run
    through the same `ImportReconciler`; retention applies; a clear error/backoff path when
    the API is unreachable (calm, no PHI in logs).
  - `docs/threat-model.md`: full new-boundary entry (data-flow diagram arrow to the vendor
    host, token asset, "no user health data leaves the device — pull only"). `dependency-audit`
    green for any OAuth/HTTP helper added.
- **Tests required:** the OAuth flow and token refresh are unit-tested against a fake HTTP
  layer (no live calls in CI); the response→`HealthSample` decoder handles the vendor's real
  payload shape + partial/malformed responses; token store round-trips; revoke clears it;
  reconciliation + retention as elsewhere.
- **Notes / detail:** strong candidate for **deferral to backlog** if p8.2 already satisfies
  the exit gate and the network surface isn't worth it for Phase 8. Written here so the
  decision is explicit, not implicit. WHOOP is the only wearable that genuinely *needs* this;
  Oura Cloud is a nice-to-have over p8.2.

#### p8.4 — (was: Whoop integration) — folded into p8.3
- **Status:** not a separate slice. WHOOP has no usable health-platform export, so a WHOOP
  connection is *only* achievable via the direct cloud API — it is the primary subject of
  **p8.3**. Kept as a numbered placeholder so the phase's slice count matches the stub;
  carries no independent work.

#### p8.5 — Passive cycle-phase inference from temperature + HRV + sleep
- **Depends on:** p8.1a (+ p8.2 for multi-device data), p3 (`AdaptivePredictor`, the
  backtester + seeded synthetic profiles), p1.3 (`deriveCycles` / `CycleStats`), p1.12
  (`currentCyclePhase` — the correctable-phase UI).
- **Requirement refs:** §10 (temperature + HRV + sleep → cycle phase; ~87% research
  accuracy; friction toward zero), §2, §6 (a correctable estimate, never a diagnosis).
- **Goal:** a pure-`core` inference that reads the passive multi-signal history and estimates
  where in the cycle the user is (notably: a **temperature-shift ovulation confirmation** and
  a **luteal-phase read**) with far less manual logging — feeding the Phase 3 predictor as an
  additional observation and surfacing through the existing correctable-phase UI.
- **Acceptance criteria:**
  - `core/lib/src/wearable/passive_phase_inference.dart` (or similar) — pure, `today`-injected,
    no `DateTime.now()`. Input: the passive temperature series (+ HRV / sleep where present),
    the logged period history, the current `CyclePrediction`. Output: a phase estimate with
    an **explicit confidence** and an honest `null` / "not enough signal" state (thin history,
    gaps, no shift detectable). Reuses p7.3's `thermalShift` primitive where it fits rather
    than a second detector.
  - It is an **input to** `AdaptivePredictor`, not a replacement — the `Predictor` seam is
    unchanged. A passively-inferred ovulation/phase is an observation the engine may weight,
    and the resulting phase is **visibly correctable** through the p1.12 quick-log flow (a
    correction always wins over an inference).
  - **Measured against the Phase 3 backtester**: the synthetic profiles gain a passive-signal
    track; the inference is scored (ovulation-day error, phase accuracy) and the combined
    predictor must **not regress** MAE or calibration on any seeded profile vs the Phase 3
    baseline. Results recorded in the slice (the p3.2 "honest headline" discipline — state
    what improved and what didn't).
  - **No alarm / no diagnosis (§6, §9(12)).** The surface says "your temperature pattern
    suggests you're likely past ovulation" — never "you did not ovulate", never a fertility
    or pregnancy verdict. Copy through the p1.9 / p4.3 seams, locked by a content test.
  - Works with zero manual logging for a user who only wears a device; degrades gracefully
    to today's behaviour when there is no passive data.
- **Tests required:** `core` — inference on each seeded profile shape (regular, PCOS,
  perimenopause, postpartum, short/long luteal): correct shift detection, honest `null` on
  thin/gappy input, confidence monotonic in signal quality, `today` injected, deterministic.
  A backtest comparison test: combined predictor MAE/calibration vs the Phase 3 baseline on
  every profile, asserting no regression. `app` — the inferred phase renders in the p1.12
  surface with its confidence and is correctable; empty state; content test for the
  non-diagnostic copy. Sweeps.
- **Notes / detail:** this is the analytical heart of the phase. Keep the model explainable
  (a documented rule/threshold pipeline over the signals, not an opaque fit) — it has to be
  defensible in the threat model and correctable by a human. No ML dependency.

#### p8.6 — Graceful multi-source arbitration (wearable + manual + platform), no conflicts
- **Depends on:** p8.1a, p8.2, p8.5; p6.4 (`conflict_review_screen`, the reconciler).
- **Requirement refs:** §9 (robust wearable sync; no data loss), §2, §3 (manual data
  authoritative).
- **Goal:** when a day has readings from several places — a typed BBT, an Apple Watch wrist
  temp, an Oura temp, a platform basal reading — olf resolves to one coherent value per day
  **without ever losing a reading or silently overwriting a correction**, with a clear
  precedence the user can see and override.
- **Acceptance criteria:**
  - A pure `core` precedence policy: **manual always wins**; among automatic sources a
    documented, deterministic order (e.g. dedicated basal device > Apple Watch sleeping wrist
    > generic platform sample), configurable-per-user only if it's cheap — otherwise a fixed,
    documented order is acceptable for v1.
  - **Resolution is reversible at the platform level (§5 ruling 2026-09-07, p8.6 negotiation
    — option (a), no schema change).** olf stores **one row per `(type, day)`**; p8.6 does
    **not** add a raw-readings archive. Instead the precedence policy runs inside the
    reconciler's existing decision point: a `crossDeviceDisagreement` (p8.2) whose rank has a
    clear winner becomes a deterministic `ReconciliationUpdate` (the winner) instead of a
    user conflict; the losing reading is **not persisted by olf** but remains in the OS
    health store, so a re-sync re-runs the policy — **"delete the winning source → the
    runner-up wins on the next sync"** holds, and "no data loss" holds because the platform
    is the source of truth and olf's import is idempotent. **v1 limitation (documented):**
    the precedence order is **fixed** for v1, and changing it later would not retroactively
    re-resolve past days without a re-pull. A local `raw_health_readings` table (giving
    offline loser-provenance + local retro-re-resolution) is **deferred to the backlog** —
    it earns its keep only alongside a per-user precedence UI, which v1 does not build. The
    resolver function itself is never persisted, either way.
  - `conflict_review_screen` (p6.4) extended to N sources: shows each source's value for a
    contested day, which one is winning and why, keep-mine / use-this-source / dismiss. No
    bulk ops (p6.4 posture).
  - Retention + backup already cover the single per-`(type, day)` row (no new persisted
    state under option (a)); the resolver is never persisted.
  - `docs/threat-model.md` review-log entry: arbitration is local, derived, reversible — no
    new asset, no new egress.
- **Tests required:** `core` — the precedence policy on every combination (manual + 1..N
  automatic → manual wins, still a conflict never an auto-update; automatic-only with a clear
  rank winner → deterministic auto-resolve; a same-rank tie → still a conflict; a re-import
  with the winning source dropped → the runner-up wins on that reconcile; a correction
  overrides all). Order-independence and determinism (same inputs any order → same plan). The
  p8.2 `crossDeviceDisagreement` tests still pass or are updated with a documented reason.
  `app` — the extended conflict screen renders N sources and each resolution action;
  retention/backup carry the resolved per-day row. Sweeps.
- **Notes / detail:** this is reconciler hardening, not a new engine. The p6.1
  `ImportReconciler` hard rules (never dupe, never clobber a manual value) are the invariants
  to preserve and extend. p8.2 already added cross-device **detection**
  (`ConflictReason.crossDeviceDisagreement`, intra-batch `(type, day)` matching) — p8.6 layers
  the deterministic **precedence** on top: pick a winner among the automatic sources instead
  of always routing a disagreement to the user.

---

**Exit gate (Phase 8) — MET (2026-09-07):** the Apple Watch wrist-temperature path and ≥1
third-party wearable are in production, opt-in, tested, retention- and backup-covered,
provenance-tagged; passive cycle-phase inference is backtested with no regression and is
correctable; multi-source days resolve without data loss or silent overwrite.

| Gate clause | Slice | PR | SHA |
|---|---|---|---|
| Apple Watch passive wrist-temperature data path (no companion), opt-in, tested, retention/backup-covered | p8.1a | #84 | `5bee215` |
| ≥1 third-party wearable in production via the health platform (Oura + Garmin), device-provenance-tagged, no new dep/network/permission | p8.2 | #85 | `c36836f` |
| Passive cycle-phase inference measured vs the Phase 3 backtester — no MAE/coverage/ovulation-error regression on any seeded profile — and fully correctable through the p1.12 surface | p8.5 | #86 | `3f41629` |
| Multi-source days (typed + platform + wearable) resolve to one coherent value with a documented deterministic precedence the user can override — no reading lost, no manual value clobbered | p8.6 | #87 | `cb0a711` |
| watchOS companion app (p8.1b) — ships if its §5 plumbing clears, else deferred | p8.1b | — | **DEFERRED → backlog** (2026-09-07) |
| Direct wearable cloud API (p8.3) — ships or recorded as a backlog deferral | p8.3 | — | **DEFERRED → backlog** (2026-09-07) |

**Phase 8 — phase-wide truths (p8.1a–p8.6):**
- **Free.** Every wearable connection and every passive-inference view ships free (§5) — no
  source gated, no "connect your Oura" upsell. The Phase 8 stub's paid-insights framing is dead.
- **The Phase 6 seam was reused, never forked.** Every new source is a new `HealthSampleType`
  mapping and/or `source_device` tag feeding the **same** `ImportReconciler`, the same
  `source` / `external_id` provenance model, the same purge-before-sync retention path, the
  same `conflict_review_screen`. No slice added a second reconcile engine or forked the
  predictor — p8.5's `PassiveInformedPredictor` is a decorator that touches only
  `fertileWindow`; p8.6 is reconciler *hardening* inside the existing decision point.
- **`core` stayed Flutter-free / `DateTime.now()`-free.** `inferPassivePhase`,
  `PassiveInformedPredictor`, `sourcePrecedenceTier` + the `known_devices` registry, and the
  synthetic passive-signal generator are all pure, clock-injected Dart in `core`. Platform
  bridges (Swift/Kotlin metadata reads) stayed in `app` / native.
- **Two additive schema bumps, each in its slice's own PR** with migration + `migration_matrix_test`
  extension + a dedicated `*_migration_test.dart` + a real `drift_dev schema dump` + a backup
  round-trip: p8.1a **v9→v10** (`bbt_entries.measurement_kind`, `to >= 10` + inner `from >= 5`
  guarded), p8.2 **v10→v11** (`source_device` on `daily_flows` + `bbt_entries`, inner
  `from >= 3` / `from >= 5`). Both §5-negotiated (`docs/plan/decisions.md`). p8.5 and p8.6
  added **no** schema — p8.6's §5 ruling was option (a): arbitration is a derived read, the
  loser stays in the OS health store, no `raw_health_readings` table (deferred to backlog).
- **Device-level provenance is additive and never a matching key.** `source_device` is a
  free-form wearable tag over the closed `source` enum; the reconciler uses it only to tell
  two devices apart on one day, an in-app edit clears it, and `RawHealthSample.toWire()` never
  emits it (inbound provenance only). p8.6's precedence classifier reads it (plus
  `measurement_kind` and the `source` enum) but stores nothing new.
- **Non-diagnostic, §6 / §9(12) at the type level.** Passive inference exposes a **one-sided**
  `enum PassivePhaseRead {ovulationLikelyPassed}` and a coarse `PassiveConfidence` — no
  "did not ovulate", no fertility verdict, no numeric score. The p1.12-wheel caption copy is
  content-locked by a test; the p8.6 conflict screen shows values, not judgements.
- **Threat model.** Every slice carries a `docs/threat-model.md` review-log entry. Across the
  whole phase: **no new adversary, trust boundary, network path / egress point, dependency,
  runtime permission, manifest/plist/entitlement, or CI gate.** The two schema bumps added
  two additive columns to existing encrypted tables (backup + retention already covered them).
  The deferred p8.3 is where a new egress *would* land — hence its deferral is a threat-model
  non-event for this phase.

**Deferred to backlog (see `backlog.md`):** the watchOS SwiftUI companion app + complication
(p8.1b — new Xcode target + HealthKit entitlement + CI compile lane) · the direct wearable
cloud API for WHOOP / Oura Cloud (p8.3 — OAuth2 client + first `OlfHttpClient` egress +
`flutter_secure_storage` token store + threat-model new-boundary entry) · HRV + sleep
*ingestion* (the `inferPassivePhase` signature already accepts `PassiveHrvSample` /
`PassiveSleepSample` but does not consume them — no new `HealthSampleType` mapped yet) · a
calendar-spaced (not reading-sequence) `thermalShift` for passive inference · a per-user
precedence-order UI for multi-source arbitration + the `raw_health_readings` archive that
would back local retro-re-resolution.

### Notes — per-slice record (frozen at close)

| Slice | PR | SHA | one-line |
|---|---|---|---|
| p8.1a | #84 | `5bee215` | Apple Watch passive wrist-temperature data path, no companion. iOS bridge maps `appleSleepingWristTemperature` (read-only, iOS-16-guarded) → `wristTemperature`; `health_import` re-types to `basalBodyTemperature` at the reconcile boundary, stores the row `measurementKind: sleepingWrist`, never pushes it back out. **Schema v9→v10** — `bbt_entries.measurement_kind TEXT NOT NULL DEFAULT 'basal'` + `enum BbtMeasurementKind`; all 5 basal-temp readers filter `== basal` → zero behaviour change (core test). §5-negotiated. Migration package in-PR. 1 `// SHORTCUT` (wrist-vs-manual "take incoming" stores `basal` — rare, re-correctable). |
| p8.1b | — | — | **DEFERRED → backlog** at the Phase 8 close (2026-09-07). Conditional slice; hard exit-gate met without it. |
| p8.2 | #85 | `c36836f` | Oura + Garmin via the health platform + device provenance — no vendor SDK, OAuth, network, or new permission. **Schema v10→v11** — nullable `source_device` TEXT on `daily_flows` + `bbt_entries` (`from >= 3` / `from >= 5` inner guards). iOS `withDevice()` reads `HKSource`/`HKDevice` name off already-fetched samples; Android reads `dataOrigin.packageName`; `toWire()` never emits it. `device_label.dart` prettifier + `contributingDevicesProvider` per-device "Apps & export" list. §5-negotiated: one minimal additive `ImportReconciler` clause — `sourceDevice` threaded through, `inserts` indexed into `byTypeDay`, new `ConflictReason.crossDeviceDisagreement` (no winner — precedence is p8.6). Single-source behaviour byte-for-byte unchanged. Migration package in-PR. No `// SHORTCUT`. |
| p8.3 | — | — | **DEFERRED → backlog** at the Phase 8 close (2026-09-07). Exit gate explicitly permits deferral; p8.2 already meets "≥1 third-party wearable". Largest security-surface change in the project — scoped as its own future work. |
| p8.4 | — | — | CUT at planning (2026-09-06) — folded into p8.3 (WHOOP has no usable platform export). Numbered placeholder only. |
| p8.5 | #86 | `3f41629` | Passive cycle-phase inference from temperature — pure `core/lib/src/wearable/passive_phase_inference.dart`, `today`-injected, no dep, no schema (derived-on-read). One-sided `enum PassivePhaseRead {ovulationLikelyPassed}` + coarse `PassiveConfidence`; picks ONE track (basal ≥9 readings else `sleepingWrist`, never blended), reuses p7.3 `thermalShift`, honest `null` on thin signal. `PassiveHrvSample`/`PassiveSleepSample` accepted but **not consumed**. `PassiveInformedPredictor implements Predictor` (interface unchanged — `CyclePrediction` gained an additive `copyWith`) re-anchors **only** `fertileWindow` → backtest MAE/calibration structurally can't regress; no passive data → byte-identical to bare `AdaptivePredictor`. Backtester: `synthetic_passive_signal.dart` + two backtest tests (no regression on every profile; inference scored directly — regular profile detects >60% w/ median ovulation error ≤2d, every profile ≤3d, heavily-gapped stays silent). Non-diagnostic p1.12-wheel caption, content-locked. 1 `// SHORTCUT` (`thermalShift` on the reading sequence not calendar days — p7.3-inherent, mitigated by density → confidence). |
| p8.6 | #87 | `cb0a711` | Graceful multi-source arbitration — pure `core` precedence policy (`source_precedence.dart` + shared vendor registry `known_devices.dart`, moved out of `app/device_label.dart`): tiers `manual`(3) > `attributedDevice`(2) > `sleepingWrist`(1) > `genericPlatform`(0). Run inside the existing `ImportReconciler`: cross-tier disagreement → higher tier wins deterministically (`ReconciliationUpdate` up, new `ReconciliationSupersede` bucket down); same tier + two recognised devices → `crossDeviceDisagreement` for the user (every p8.2 test unchanged); 3+ same-tier → one folded conflict (`alsoContending`). `manual` disagreement is **always** a conflict. `conflict_review_screen` reworked to N source rows + `reduceSpokenDetail` redaction. **§5 ruling: option (a), NO schema change** — loser stays in the OS health store, re-sync re-resolves; `raw_health_readings` deferred; acceptance criterion relaxed to "reversible at the platform level" + documented v1 limitation. **PR gate bounced once** (stale `byTypeDay` on the stored-row tier-win path → possible silent tier inversion / skipped p8.2 conflict) → fix `2c01b16` + 4 running-winner tests. Known benign corner: stored lower-tier row + ≥2 same-higher-tier-source no-`externalId` same-day readings → arbitrary tie-break either way. No net `// SHORTCUT`. |
| close | #— | `—` | Exit gate filled, `overview.md` row 8 → DONE, `architecture.md` refresh for p8.6, p8.1b + p8.3 marked DEFERRED, this frozen record + phase-wide-truths + deferred-backlog blocks; carries the batched local-`main` bookkeeping stack. |

(The close-row PR/SHA is backfilled once the close PR merges.)
