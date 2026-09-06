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
  Ring", "from Apple Watch") needs more than that enum. Prefer a nullable `source_device`
  text column / free-form tag over a closed enum, added as a **schema change** — §5 stop, and
  it ships with its migration + `migration_matrix_test` extension + a dedicated
  `*_migration_test.dart` + a backup round-trip in the same PR (the p6.1 / p7.5 / p7.6
  precedent; `docs/release-checklist.md` "Schema change" block). `schemaVersion` is **9**
  after Phase 7.
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
    mapped to the already-declared `HealthSampleType.wristTemperature` (°C). The other two
    declared-but-unused types: **HRV** (`heartRateVariabilitySDNN`) and **sleep**
    (`sleepAnalysis` asleep minutes) — map them here *if* it is a small, natural extension of
    the same query path; otherwise declare them still-unmapped and note it for p8.5. Do not
    let HRV/sleep balloon this slice.
  - **Storage decision — flag at negotiation.** `appleSleepingWristTemperature` is a
    *sleeping wrist* measurement, not a *basal body* temperature, and on some Apple surfaces
    it is a nightly deviation from a personal baseline rather than an absolute. Writing it
    straight into `bbt_entries.tempCelsius` conflates two measurements. The Worker assesses
    and proposes one of: (a) a `measurement_kind` discriminator on `bbt_entries` (basal vs
    sleeping-wrist), (b) a dedicated `wrist_temperature` table, or (c) documented reuse of
    `bbt_entries` with the semantic difference recorded. (a) and (b) are **schema changes**
    — §5 stop, full migration deliverable in the PR.
  - Imported wrist-temperature readings carry `source = appleHealth` **and** a device tag
    (see the phase-wide "device-level provenance" constraint — likely the first user of a new
    nullable `source_device` column; §5 stop if so) so the UI can say "from Apple Watch".
  - Reconciliation is the existing `ImportReconciler` unchanged: a manual BBT entry for a day
    is never overwritten by a wrist-temperature import (it becomes a reviewable conflict); a
    prior wrist-temperature import for the same day updates in place via `external_id`.
  - **Surface:** the BBT / temperature view shows passively-captured readings distinctly from
    typed ones ("Apple Watch · captured while you slept"), and every passive reading is
    editable / correctable / deletable through the existing flow. A per-source status line in
    the "Apps & export" section (connected · last sync · count), `reduceSpokenDetail`-redacted.
  - Retention (p2.3) ages out wrist-temperature readings on the same window as every dated
    table; backup/restore round-trips them; if a new table/column is added it joins
    `BackupService.tableOrder` + `RetentionService.deleteWhere`.
  - `docs/threat-model.md`: review-log entry — new asset (passive wrist-temperature readings,
    device tag) in the existing encrypted local DB; **no new egress** (data arrives over the
    existing local HealthKit IPC), no new permission (same HealthKit entitlement), no new
    dependency. `docs/local-database.md` updated if the schema moves.
  - New `screen_nav.dart` surface(s) for any new/changed screen; five a11y sweeps green; dark
    mode; `reduceSpokenDetail` on temperatures.
- **Tests required:** `core` — `wristTemperature` sample round-trips the model invariant
  (°C); `ImportReconciler` treats a wrist-temp import against a manual BBT day as a conflict,
  against a prior wrist-temp day as an in-place update; precedence with an existing
  `appleHealth` basal reading is deterministic. If schema moves: `migration_matrix_test`
  extended + a dedicated `wrist_temperature_migration_test.dart` (hand-rolled prior version
  on disk → new) + a backup round-trip carrying a real wrist-temp row across the migration.
  `app` — the HealthKit channel wrapper decodes a wrist-temperature payload (mocked platform
  channel); the import service applies inserts + skips conflicts; the temperature view
  renders passive vs manual distinctly and a passive reading is correctable; per-source
  status line; sweeps.
- **Notes / detail:** hand-rolled bridge only — **no `health` package** (p6.2 rejected it;
  no `BASAL_BODY_TEMPERATURE`/wrist-temp coverage and it forces an SDK-floor bump). The Swift
  side is a thin addition to the existing `HealthKitBridge`. Real Apple Watch capture is a
  p0.5 device-smoke item (no watch hardware in CI). Keep HRV/sleep minimal here; p8.5 is
  where they earn their place.

#### p8.1b — Apple Watch companion app (SwiftUI) — glanceable cycle view + complication
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
- **Depends on:** p8.1a (the `wristTemperature`/HRV/sleep ingestion path + `source_device`
  provenance), p6.3 (Health Connect bridge, for the Android side).
- **Requirement refs:** §2 (Oura, Garmin), §10, §9 (robust sync), §5 (free — not paywalled).
- **Goal:** a user whose Oura Ring or Garmin device already syncs to Apple Health / Health
  Connect sees that temperature (+ HRV / sleep) in olf, **labelled by device** ("from your
  Oura Ring"), through the same import path — **no vendor SDK, no OAuth, no network**.
- **Acceptance criteria:**
  - The import path reads the same `HealthSampleType`s regardless of which device wrote them;
    the `source_device` tag (from p8.1a) is populated from the platform sample's
    `HKSource` / `HKDevice` (iOS) or the Health Connect origin (Android) so olf can attribute
    a reading to Oura / Garmin / Apple Watch / another app.
  - A per-device status surface in "Apps & export": which devices have contributed data, last
    sync, counts — `reduceSpokenDetail`-redacted. Disconnecting olf from the platform keeps
    the readings; there is no per-device "connect" beyond the platform grant.
  - Reconciliation across devices is deterministic (p8.6 defines the precedence order; this
    slice must at least not dupe or clobber — two devices reporting the same day is a
    single reconciled reading + a reviewable conflict if they disagree materially).
  - No new dependency, no new permission beyond the existing HealthKit / `health.*` grants,
    no network. `docs/threat-model.md` review-log entry — provenance is now finer-grained,
    still the same asset class + same local IPC, no new egress.
  - `docs/health-platform-interop.md` updated with the device-attribution behaviour and the
    iOS-vs-Android capability asymmetry for third-party device metadata.
- **Tests required:** `core` — device tag flows from a raw sample through
  `healthSampleFromRaw` into storage; a two-device same-day disagreement is a conflict, a
  two-device agreement is one reading. `app` — status surface lists contributing devices
  from mocked platform payloads; Oura-style and Garmin-style payloads both decode. Sweeps if
  a screen changes.
- **Notes / detail:** Garmin's direct **Garmin Health API** is a server-to-server partnership
  program, not a simple OAuth app — explicitly **out of scope** here; the platform path is
  the supported route. Oura *also* has a cloud API (p8.3) — this slice is the zero-dependency
  path that covers most real users. This slice can satisfy the exit gate's "at least one
  third-party wearable in production" on its own.

#### p8.3 — Direct wearable cloud API (the §5-heavy path) — Oura Cloud and/or WHOOP
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
  - Every raw reading is **retained** (provenance-tagged); the "resolved" day value is a
    derived read, not a destructive merge — changing the precedence or deleting the winning
    source re-resolves without data loss.
  - `conflict_review_screen` (p6.4) extended to N sources: shows each source's value for a
    contested day, which one is winning and why, keep-mine / use-this-source / dismiss. No
    bulk ops (p6.4 posture).
  - Retention + backup cover every raw reading; the resolver is never persisted.
  - `docs/threat-model.md` review-log entry: arbitration is local, derived, reversible — no
    new asset, no new egress.
- **Tests required:** `core` — the precedence policy on every combination (manual + 1..N
  automatic; automatic-only; ties; a deleted winning source re-resolves; a correction
  overrides all). Order-independence and determinism. `app` — the extended conflict screen
  renders N sources and each resolution action; retention/backup carry all raw rows. Sweeps.
- **Notes / detail:** this is reconciler hardening, not a new engine. The p6.1
  `ImportReconciler` hard rules (never dupe, never clobber a manual value) are the invariants
  to preserve and extend.

---

**Exit gate (Phase 8):** the Apple Watch wrist-temperature path (p8.1a) **and** at least one
third-party wearable (p8.2 — Oura/Garmin via the platform) are in production, opt-in, tested,
retention- and backup-covered, provenance-tagged; passive cycle-phase inference (p8.5) is
measured against the Phase 3 backtester with no MAE/calibration regression on the seeded
profiles and is fully correctable through the p1.12 surface; multi-source days resolve
without data loss or silent overwrite (p8.6). The watch companion (p8.1b) ships if its §5
plumbing (new target + entitlement + CI) clears; the direct cloud API (p8.3) ships or is
recorded as a backlog deferral. Phase-wide: `core` stayed Flutter-free / `DateTime.now()`-free;
every source opt-in and default-off; nothing paywalled (§5); any schema change shipped with
its migration + matrix + `*_migration_test` + backup round-trip in the same PR; new network
egress (if any) threat-modelled with the data-flow diagram updated.

(PR / SHA blanks filled at phase close.)
