### Phase 6 — Health-platform interop & doctor export

**Requirement refs:** §2 (interop; data export for doctor visits), §3 (no
unencrypted health data leaving the vault; retention window applies to synced + exported data),
§4 (interop with Apple Health / Health Connect; reliability), §6 (not a medical device —
disclaimers on any exported report), §9(11) (don't lose data across the sync boundary).

**What this phase is.** The app currently owns all of its data. Phase 6 opens two new,
deliberate, user-controlled boundaries: (a) a *bidirectional* bridge to the OS health platform —
Apple HealthKit and Android Health Connect — for menstrual flow, BBT / body & wrist temperature,
and sleep; and (b) an on-device, offline **doctor-ready report** the user can hand to a
clinician. Both are opt-in, both respect the p2.3 retention window and the p2.5 default-off
consent model, and every platform SDK sits behind a `core` interface (the "swap the plugin"
requirement) so the desktop shell (Phase 13) and any future backend are unaffected.

**Slice reshape (orchestrator, 2026-09-05).** The original one-liners were p6.1 HealthKit /
p6.2 Health Connect / p6.3 reconciliation / p6.4 doctor export / p6.5 "behind our own
interface." Expanded: the interface + reconciliation engine + provenance schema are the
*foundation* every other slice builds on, so they move first (p6.1); the two platform
implementations follow (p6.2 iOS, p6.3 Android); sync becomes genuinely two-way with a visible
status surface in p6.4; the doctor export is p6.5. Same five slice numbers, resequenced.

**Phase-wide constraints.**
- **`core` stays Flutter-free / `DateTime.now()`-free.** The gateway interface, the sample
  model, the reconciliation engine and the report document model all live in `core` as pure
  Dart; only the platform impls and the PDF rendering live in `app`.
- **New runtime dependencies are expected but gated.** First phase since Phase 1 to add any.
  Each candidate (`health` for p6.2/p6.3, `pdf` for p6.5) is **named in its slice row with a
  rationale** and must clear, in the claiming PR: the `dependency-audit` against
  `.github/dependency-denylist.txt` *transitively*, a GPLv3-compatible licence, and the
  "no ad / analytics / telemetry surface" bar every prior dep met (`local_auth`, `file_picker`).
  A candidate that fails any gate falls back to a hand-rolled `MethodChannel` (p5.4 precedent) —
  note the outcome in the slice log; do **not** silently swap in a different package (§5 stop).
- **One schema bump, in p6.1: `schemaVersion` 6 → 7** — provenance columns on the synced tables.
  Ships with its migration, `migration_matrix_test` extended to v7, and the
  backup/restore-across-migration round trip — same PR, per the hard rule and
  `docs/release-checklist.md`'s "Schema change" block.
- **New platform capabilities are threat-model events.** p6.1 adds the Phase 6 opening-gate
  Review-log entry to `docs/threat-model.md`; p6.2 and p6.3 each update Assets / Trust
  boundaries / Data flow / Mitigations for the platform they add; p6.5 logs the new
  user-initiated export egress path (same class as the p1.10 backup export). The
  `threat_model_doc_test` guard stays green throughout.
- **Retention + consent.** Nothing syncs or exports without an explicit, default-off, revocable
  opt-in per platform / per direction (p2.5; MHMDA separate-consent-for-sharing). The p2.3
  retention window applies to imported data and to anything written back or exported
  (purge-before-export, p2.3 precedent). The in-app privacy policy (`docs/privacy-and-lock.md` +
  the policy screen) discloses the integration.
- **No backend, no network.** HealthKit / Health Connect are local IPC; the `OlfHttpClient` TLS
  chokepoint (p2.6) is N/A here — state that in the threat-model update rather than leaving it
  ambiguous.

#### p6.1 — Interop foundation: gateway interface, sample model, reconciliation engine, provenance schema (v7)
- squash `ed81ac5` · PR #65 · **Depends on:** none (first Phase 6 slice; carries `main` from the Phase 5 close + p1.12)
- **Owner:** worker: phase1
- **Branch / worktree:** `feat/p6.1-interop-foundation` · `../olf-wt/p6.1` off `main` @ `f9780bd` (#64)
- **Requirement refs:** §2, §3, §9(11); §1.4 DoD (schema change ⇒ migration + test)
- **Goal:** the pure-Dart spine every other Phase 6 slice plugs into — a typed external-sample
  model, a platform-agnostic gateway interface with a fake, a deterministic import-reconciliation
  engine that never duplicates and never clobbers a user value, and the schema provenance that
  makes "never clobber" real.
- **Design (orchestrator, 2026-09-05):**
  - **`HealthSample` model** (`core/lib/src/health/health_sample.dart`) — `@immutable`, house
    style. `HealthSampleType` enum: `menstrualFlow`, `basalBodyTemperature`, `bodyTemperature`,
    `wristTemperature`, `sleep` (start with these five; trivially extensible). Each sample:
    `type`, `startAt` / `endAt` (`endAt == startAt` for point samples), `value` + `unit` (a
    small `HealthUnit` enum — `celsius`, `flowLevel`, `minutes`; no free-text units), `source`
    (`HealthDataSource` enum: `manual`, `appleHealth`, `healthConnect`), nullable `externalId`
    (the platform's stable UUID, for round-trip identity). `==` / `hashCode`. No Flutter, no
    `DateTime.now()`.
  - **`HealthPlatformGateway` interface** (`core/lib/src/health/health_platform_gateway.dart`) —
    `requestAuthorization(Set<HealthSampleType> types, {required HealthAccess access})` (`access`
    = read / write / readWrite), `authorizationStatus(...)`, `read({types, from, to})`,
    `write(List<HealthSample>)`, optional `delete(...)`, `bool get isAvailable`. Each method
    documents the "platform unavailable ⇒ `isAvailable == false`, calls throw
    `HealthPlatformUnavailable`" contract. Ships a `FakeHealthPlatformGateway` (in-memory,
    scriptable auth outcomes + seeded sample store) in `core` for downstream tests.
  - **`ImportReconciler`** (`core/lib/src/health/import_reconciler.dart`) — pure. Input: the
    user's existing rows for a type+range (a small `LocalSampleView` DTO carrying `source` +
    `externalId` + key fields) and a `List<HealthSample>` incoming from a gateway. Output: a
    `ReconciliationPlan` — `inserts`, `updates` (matched by `externalId`, else by `(type, day)`
    when both sides are same-source), `conflicts` (incoming disagrees with a `source == manual`
    row, or with a differently-sourced row), `skipped` (exact duplicates). **Hard rules:** a
    `source == manual` local row is never in `updates`, only ever `conflicts`; matching is
    deterministic and order-independent; the plan is a value object the caller applies — the
    reconciler touches no storage. Editing a previously-imported row is expected to flip its
    `source` to `manual`; spec that here, implement the flip in p6.4 when the write path exists
    (or here if it is a couple of lines).
  - **Schema v6 → v7** — add `source` (text, not null, default `'manual'`) and `externalId`
    (text, nullable) to `BbtEntries` and `DailyFlows` in `core/lib/src/db/tables.dart`; bump
    `schemaVersion` to 7; `onUpgrade` `from <= 6` block does `m.addColumn` ×4. **This is the
    first migration that alters an existing table** — `core/tool/dump_historical_schemas.dart`
    currently reconstructs v1..v(N-1) by truncating the latest snapshot's entity list, valid
    only while history is createTable-only. Rework the tool: anchor v1..v5 reconstruction on the
    committed **v6** snapshot (the last additive-only version) and treat **v7** as its own
    freshly-dumped real snapshot; update the header comment explaining why v6 is the anchor.
    Regenerate `drift_schemas/drift_schema_v7.json` + the `test/db/generated/` verifier helpers
    per `docs/release-checklist.md`.
  - **`docs/threat-model.md`** — add the "2026-09-05 — Phase 6 opening gate" Review-log entry
    (same shape as the Phase 5 one): names the two boundaries the phase will open, states
    nothing is open yet in this slice, notes the `OlfHttpClient` TLS chokepoint is N/A (local
    IPC, no network). Keep `threat_model_doc_test` green.
  - **No new dependency. No `app/` UI. No manifest / Info.plist change.** Pure `core` + schema + docs.
- **Acceptance criteria:**
  - `core/lib/src/health/{health_sample,health_platform_gateway,import_reconciler}.dart` +
    `FakeHealthPlatformGateway`, all exported from `core/lib/olf_core.dart`.
  - `schemaVersion == 7`; migration adds exactly the four columns; `flutter analyze
    --fatal-infos` clean; `build_runner` shows no `.g.dart` drift.
  - `drift_schemas/drift_schema_v7.json` + refreshed `test/db/generated/` committed;
    `dump_historical_schemas.dart` reworked and its output for v1..v6 byte-identical to the
    committed snapshots.
  - `migration_matrix_test` extended: `from` loop covers 1..6; new assertions that
    `bbt_entries` / `daily_flows` gain `source='manual'` + null `externalId` on every pre-v7 row
    after migration; the v(old)→migrate→backup→restore round trip passes for v7.
  - `ImportReconciler` never places a `manual` row in `updates`; plan is order-independent
    (shuffled-input test).
- **Tests required:** `core/test/health/health_sample_test.dart` (equality, extensibility),
  `core/test/health/import_reconciler_test.dart` (insert / update-by-externalId / update-by-day /
  conflict-vs-manual / conflict-vs-other-source / exact-dupe-skip / empty sides / shuffled-order
  determinism), `core/test/health/fake_gateway_test.dart` (the fake honours its own contract),
  `core/test/db/migration_matrix_test.dart` extended as above. Existing core + app suites stay green.
- **Notes / detail:** worker picks the exact DTO shapes and file layout. If the
  `source`-flip-on-edit is more than a couple of lines in the existing repos, defer it to p6.4
  with a one-line backlog note. Do **not** add `bodyTemperature` / `wristTemperature` platform
  mapping yet — model only; mapping is p6.2/p6.3.
- **Build detail (worker: phase1):**
  - **`core/lib/src/health/health_sample.dart`** — `HealthSampleType` (5), `HealthUnit`
    (`celsius` / `flowLevel` / `minutes`), `HealthDataSource` (`manual` / `appleHealth` /
    `healthConnect`), `HealthAccess` (`read` / `write` / `readWrite`) enums + `@immutable`
    `HealthSample` (`type`, `startAt`, `endAt`, `value` double, `unit`, `source`, `externalId?`)
    with value `==` / `hashCode`, a `copyWith`, `isPointSample` (`endAt == startAt`) and an
    asserting ctor (`!endAt.isBefore(startAt)`; `wristTemperature`/`bodyTemperature`/
    `basalBodyTemperature` ⇒ `unit == celsius`; `menstrualFlow` ⇒ `flowLevel`; `sleep` ⇒
    `minutes`). Pure — no Flutter, no `DateTime.now()`.
  - **`core/lib/src/health/health_platform_gateway.dart`** — `HealthPlatformUnavailable`
    (`Exception`, message), abstract `HealthPlatformGateway` (`isAvailable`,
    `requestAuthorization(Set<HealthSampleType>, {required HealthAccess access})` →
    `HealthAuthResult`, `authorizationStatus(Set<HealthSampleType>, {required HealthAccess})` →
    `HealthAuthStatus` enum `granted` / `denied` / `notDetermined`, `read({Set<HealthSampleType>
    types, DateTime from, DateTime to})` → `List<HealthSample>`, `write(List<HealthSample>)`,
    `delete({type, from, to})`). Doc comment on every method spells the unavailable-⇒-throw
    contract. `FakeHealthPlatformGateway` — ctor flags (`available`, scripted
    `authOutcome`/`statusByType`), in-memory `List<HealthSample>` store (`seed(...)`), `read`
    filters by type+range, `write` upserts by `externalId`, `delete` removes by type+range;
    throws `HealthPlatformUnavailable` from every data call when `!available`; records
    `authRequests` for assertions.
  - **`core/lib/src/health/import_reconciler.dart`** — `LocalSampleView` DTO (`localId` opaque
    String, `type`, `day` (date-only `DateTime`), `value`, `unit`, `source`, `externalId?`),
    `ReconciliationOutcome` items (`ReconciliationInsert(sample)`,
    `ReconciliationUpdate(localId, sample)`, `ReconciliationConflict(localId, local, incoming,
    reason)` with `ConflictReason` enum `manualDisagreement` / `crossSourceDisagreement`,
    `ReconciliationSkip(localId, sample)`), `ReconciliationPlan` (`inserts` / `updates` /
    `conflicts` / `skipped`, all unmodifiable; `isEmpty`; `==`/`hashCode` for test determinism).
    `ImportReconciler.reconcile({required List<LocalSampleView> local, required
    List<HealthSample> incoming, double tolerance = 0.01})` — indexes local by `externalId` then
    by `(type, ymd)`; for each incoming (processed in a stable `startAt`-then-`externalId` sort
    so output is order-independent): exact match (same value within `tolerance`, same source) ⇒
    skip; `externalId` match with a `manual` local ⇒ conflict(`manualDisagreement`);
    `externalId` match same non-manual source, value differs ⇒ update; `(type, day)` match,
    both non-manual same source, value differs ⇒ update; `(type, day)` match vs `manual` local ⇒
    conflict(`manualDisagreement`); `(type, day)` match vs different source ⇒
    conflict(`crossSourceDisagreement`); no match ⇒ insert. Deterministic, storage-free.
    `source`-flip-on-edit is **deferred to p6.4** (needs the write path; backlog note added to
    p6.4).
  - **`core/lib/olf_core.dart`** — `export 'src/health/health_sample.dart';`,
    `'src/health/health_platform_gateway.dart';`, `'src/health/import_reconciler.dart';`.
  - **`core/lib/src/db/tables.dart`** — `BbtEntries` + `DailyFlows` each gain
    `TextColumn get source => text().withDefault(const Constant('manual'))();` and
    `TextColumn get externalId => text().nullable()();`.
  - **`core/lib/src/db/app_database.dart`** — `schemaVersion => 7`; `onUpgrade` gains a trailing
    `if (from < 7 && to >= 7) { … }` block that does `m.addColumn` ×4, **guarded**: an inner
    `if (from >= 3)` adds `source` + `external_id` to `daily_flows` (introduced v3) and an
    `if (from >= 5)` adds them to `bbt_entries` (introduced v5). When `from` predates a table's
    own version the earlier `m.createTable` already builds it in the v7 shape, so an
    unconditional `addColumn` would duplicate a column; the outer `to >= 7` guard keeps the
    single-step `migration_matrix_test` targets (`to < 7`) from acquiring the v7 columns early.
    Regenerated `app_database.g.dart` via `build_runner` (no `.g.dart` drift).
  - **`core/tool/dump_historical_schemas.dart`** — reworked: `_reconstructFromV6` truncates the
    committed **v6** snapshot's `entities` / `fixed_sql` to `_tableCountAtVersion[v]` for
    v ∈ 1..5 (unchanged counts `{1:1, 2:2, 3:3, 4:5, 5:8}`); v6 is copied through verbatim; v7
    is **not** synthesised — it is produced by a real `drift_dev schema dump` and only
    validated here (fails loudly if `drift_schema_v7.json` is missing or its `schemaVersion !=
    7`). Header comment rewritten: v6 is the anchor because it is the last additive-only
    (createTable-only) version; v7 is the first ALTER and must be dumped, not reconstructed.
  - **`core/drift_schemas/drift_schema_v7.json`** — fresh `dart run drift_dev schema dump
    lib/src/db/app_database.dart drift_schemas/`. **`core/test/db/generated/`** — regenerated
    (`schema.dart` + `schema_v7.dart`) via `dart run drift_dev schema generate`.
  - **`core/test/db/migration_matrix_test.dart`** — `from` loops widened `1..5` → `1..6`;
    `migrateAndValidate(db, 7)`; new per-row assertions after a `<= 6 → 7` migration that every
    surviving `bbt_entries` / `daily_flows` row has `source == 'manual'` and `external_id IS
    NULL`; the backup→restore round trip re-targets v7 (`BackupService` `appSchemaVersion == 7`).
    `_tableCountAtVersion` unchanged (v7 adds columns, not tables — count stays 11).
  - **`docs/threat-model.md`** — "2026-09-05 — Phase 6 opening gate" Review-log entry after the
    Phase 5 closing one: names the two boundaries Phase 6 will open (OS health platform bridge;
    doctor-ready export), states **nothing is open in p6.1** (pure `core` + schema + docs — no
    platform SDK, no manifest change, no network), notes `OlfHttpClient` TLS chokepoint is
    **N/A** (HealthKit / Health Connect are local IPC), no change to Assets / Adversaries /
    Trust boundaries / Mitigations / Residual risks yet — those land in p6.2/p6.3/p6.5.
    `_currentPhase` stays 5 (Phase 6 header still `TODO`), so `threat_model_doc_test` stays
    green on the Phase 5 entry; the new entry is additive.
  - **`docs/release-checklist.md`** — the existing "Schema change" block already covers v7; add
    a one-line note that v7 is the first ALTER migration so `dump_historical_schemas.dart` no
    longer reconstructs the newest version — it must be `drift_dev schema dump`ed.
  - **Tests:** `core/test/health/health_sample_test.dart`,
    `core/test/health/import_reconciler_test.dart`, `core/test/health/fake_gateway_test.dart`,
    extended `migration_matrix_test.dart`. **Constraints honoured:** no new dependency (Dart or
    platform); `core` stays Flutter-free / `DateTime.now()`-free; no `app/` change; no CI
    workflow change (new tests ride the existing `test` job).

#### p6.2 — Apple HealthKit gateway (iOS)
- squash `76c31cd` · [PR #66](https://github.com/Abbo0dio/olf/pull/66) · **Depends on:** p6.1
- **Requirement refs:** §2, §3, §4
- **Goal:** a real `HealthPlatformGateway` for iOS — read + write menstrual flow, BBT / body /
  wrist temperature, sleep — reachable from a default-off, opt-in "Connect Apple Health" control
  that runs one reconciled import.
- **Design (orchestrator, 2026-09-05):**
  - **Platform bridge (orchestrator §5 ruling, 2026-09-05):** hand-rolled **`olf/health`
    `MethodChannel`** (Swift, on the Runner target — p5.4 pattern), **not** the `health` pub
    package. Worker's §5 audit found `health` (13.3.1 pinned / 13.3.2 latest) exposes **no
    `BASAL_BODY_TEMPERATURE`** in any version — olf's primary temperature signal (`bbt_entries`)
    would need a hand-rolled channel regardless — and adopting it would also force
    iOS 14→15-equivalent + Android `minSdk` 24→26 floor bumps and add 6 transitive packages,
    all for menstrual-flow sync only. A focused bridge we fully control is the better trade for
    olf's deliberately narrow sync surface (flow + BBT, foreground only). The channel methods
    mirror the `core` `HealthPlatformGateway`: `requestAuthorization` / `authorizationStatus` /
    `read` / `write` / `delete`. **No new pubspec dependency. No SDK-floor bump.** The `core`
    interface is unchanged; the Dart impl lives in `app/lib/src/health/`.
  - **iOS native:** HealthKit capability + entitlement on the Runner target;
    `NSHealthShareUsageDescription` + `NSHealthUpdateUsageDescription` in `Info.plist` with
    honest, non-marketing copy. No new CocoaPods. ATS stays strict.
  - **Type mapping (hand-rolled channel):** `menstrualFlow` ↔
    `HKCategoryTypeIdentifier.menstrualFlow`, `basalBodyTemperature` ↔
    `HKQuantityTypeIdentifier.basalBodyTemperature`. The other three p6.1 model types
    (`bodyTemperature`, `wristTemperature`, `sleep`) stay declared in the `core` interface but
    the iOS bridge returns unsupported / empty for them with a logged note — they have no olf
    table yet; wire them when a consuming feature lands. Unit conversions centralised and
    unit-tested on the Dart side.
  - **UI:** a single "Connect Apple Health" tile in Settings → new "Apps & export" section.
    Default off. Tapping it explains what flows **in** and **out**, then triggers
    `requestAuthorization(readWrite)`; on grant, reads the last N months, feeds the
    `ImportReconciler`, applies the plan (inserts + non-conflicting updates), shows a plain
    summary ("added 12, updated 3, 2 need your review"). Revoking is "disconnect" + a pointer to
    iOS Settings. a11y: tile + summary go through `screen_nav.dart` (new surface); dark mode;
    `reduceSpokenDetail` on the summary if it names counts of a health type.
  - **Non-iOS:** the `olf/health` channel is unimplemented off iOS (`MissingPluginException` →
    the gateway reports `isAvailable == false`), so the tile is hidden on Android / desktop.
    p6.3 adds the Health Connect equivalent. `isAvailable == false` path tested.
  - **threat-model:** update Assets (HealthKit store), Trust boundaries (iOS Health sandbox),
    Data flow (new in/out arrows), Mitigations (opt-in, scoped types, no network).
    `release-checklist.md`: HealthKit entitlement + usage-string device check.
- **Acceptance criteria:**
  - iOS HealthKit impl behind the p6.1 interface; DI wires the real gateway on iOS, an
    `unavailable` gateway elsewhere.
  - `Info.plist` usage strings + entitlement present; `flutter analyze` + both CI build-matrix
    jobs (apk + ios) green; `dependency-audit` green (no new pubspec dependency — hand-rolled
    channel per the §5 ruling; iOS permission surface is the HealthKit entitlement + the two
    usage strings, no `<uses-permission>` change).
  - Settings tile default-off, opt-in, revocable; first connect runs a reconciled import + a
    summary; no crash when permission denied.
  - New `screen_nav.dart` surface; all five sweeps green, no new skips.
- **Tests required:** `app/test/health/healthkit_gateway_test.dart` (type + unit mapping,
  unavailable path — mock the plugin channel), `app/test/health/connect_health_flow_test.dart`
  (widget: default-off; opt-in dialog names both directions; grant → reconciler invoked with a
  `FakeHealthPlatformGateway`; summary rendered; denied → calm message), sweeps via
  `screen_nav.dart`. Native HealthKit auth on a real device → p0.5-style manual smoke list (no
  Xcode in CI/worker env — CI validates the build only).
- **Notes / detail:** worker owns the Settings section layout and the first-import month count
  (propose, note it). If the Swift bridge surfaces something structural (a Swift-version pin, a
  new entitlement class beyond HealthKit, an AGP bump) → §5 stop, report it.

#### p6.3 — Android Health Connect gateway
- **PR:** [#67](https://github.com/Abbo0dio/olf/pull/67) · **Depends on:** p6.1, p6.2 (shared `olf/health` wire contract + Dart gateway/codec)
- **Requirement refs:** §2, §3, §4
- **Goal:** the Android half — a real `HealthPlatformGateway` over Health Connect for the two
  wired types, the same opt-in tile now enabled on Android, plus the Google Fit deprecation note.
- **Design (orchestrator §5 re-ruling, 2026-09-05 — supersedes the `health`-package framing,
  consistent with the §7 `health` evaluate-and-reject entry):**
  - **Platform bridge:** hand-roll the **Android half of `olf/health`** in **Kotlin** on
    `MainActivity`, mirroring p6.2's Swift `HealthKitBridge`. Same channel methods
    (`isAvailable` / `requestAuthorization` / `authorizationStatus` / `read` / `write` /
    `delete`) and the **same wire contract** as p6.2's `health_channel.dart` — the Dart side
    (channel wrapper + pure codec + `HealthImportService` + Settings widget) is reused unchanged;
    only the native peer differs. The Kotlin bridge translates Health Connect's menstruation-flow
    scale (`unknown=0/light=1/medium=2/heavy=3`) to and from the HealthKit wire scale the Dart
    codec speaks (`unspecified=1/light=2/medium=3/heavy=4`), so the shared codec needs no change.
    **No `health` pub package** (rejected in p6.2).
  - **Gradle dependency (§5, pre-authorized in-row):** add
    **`androidx.health.connect:connect-client`** (Google first-party AndroidX — the only
    supported Android health API; Google Fit APIs shut down 2026). A Gradle/AGP dep declared in
    `app/android/app/build.gradle.kts`, **not** a pub package → `app/pubspec.yaml` /
    `pubspec.lock` stay clean. Pinned to an explicit stable version (no `+`/dynamic). **Gate:**
    the `dependency-audit` permission-diff must show *only* the Health Connect permission set for
    the wired types + the rationale `<intent-filter>` — nothing broader — explained in the PR body.
  - **`minSdk` 24 → 26 (§5, pre-authorized in-row):** `connect-client` requires API 26+. Bump
    `minSdk` to `26` in `build.gradle.kts`. This *aligns* the actual build floor with the
    already-documented minimum (`docs/plan/conventions.md` + `docs/performance-budget.md`
    both say "Android 8+ (API 26+)") — no doc change for the target; the actual-config bump is
    noted in the Log line + the threat-model entry. (This is the floor bump p6.2 avoided because
    the hand-rolled HealthKit bridge didn't need it — Health Connect genuinely does.)
  - **Wired types — match p6.2 exactly:** only `menstruation` (Health Connect
    `MenstruationFlowRecord` ↔ p6.1 `menstrualFlow`) and `BasalBodyTemperatureRecord` (↔
    `basalBodyTemperature`). The other three p6.1 model types (`bodyTemperature`,
    `wristTemperature`, `sleep`) stay declared in the `core` interface; the Android gateway
    returns unsupported/empty for them with a logged note — same as the iOS bridge — keeping the
    shared `ImportReconciler` + Settings widget symmetric. The iOS-vs-Android capability
    asymmetry (Health Connect *does* have `SkinTemperatureRecord` read+write; HealthKit's wrist
    temperature is sleeping-only / read-only) is noted in one place in
    `docs/health-platform-interop.md` for when a consuming feature lands.
  - **Android manifest:** exactly `android.permission.health.READ_MENSTRUATION` /
    `WRITE_MENSTRUATION` / `READ_BASAL_BODY_TEMPERATURE` / `WRITE_BASAL_BODY_TEMPERATURE` — those
    four, for the two wired types, each with an adjacent `audited:` comment. Plus the Health
    Connect permissions-rationale `<intent-filter>`
    (`androidx.health.connect.action.SHOW_PERMISSIONS_RATIONALE`) on `.MainActivity`, and a
    `<queries><package android:name="com.google.android.apps.healthdata" />` entry so
    `getSdkStatus` can see the provider on API 30+ (package-visibility, not a permission).
    Availability: Health Connect not installed / SDK unavailable → tile hidden,
    runtime `isAvailable == false`.
  - **UI:** the same tile pattern as p6.2, now enabled on Android. One shared widget; a
    `healthPlatformNameProvider` supplies "Apple Health" / "Health Connect" / "your health app"
    for the copy, and a matching revoke-hint string. `healthPlatformGatewayProvider` picks
    `HealthConnectGateway` on Android / `HealthKitGateway` on iOS / `UnavailableHealthGateway`
    elsewhere; `healthAvailableProvider` becomes a `FutureProvider<bool>` so the Android runtime
    SDK probe can gate the section. Same reconciled-import → summary flow,
    `reduceSpokenDetail` redaction, calm SnackBars on denied/unavailable.
  - **Docs:** new `docs/health-platform-interop.md` — Google Fit deprecation note (APIs shut
    down 2026, Health Connect is the sole Android path, no Google Fit integration by design) +
    the one-place iOS-vs-Android capability asymmetry table. `release-checklist.md` — Health
    Connect permission-set + rationale-intent device check. `threat-model.md` — extend Trust
    boundary #8 to "App ↔ OS health platform (both OSes)", update Assets / Data flow /
    Mitigations, and add a "2026-09-05 — Phase 6 / p6.3 landing" Review-log entry.
- **Acceptance criteria:**
  - Android impl behind the p6.1 interface over the hand-rolled channel; DI wires it on Android;
    iOS unaffected.
  - Manifest carries exactly the four-name health permission set (each `audited:`) + the
    rationale `<intent-filter>`; `dependency-audit` green, permission-diff explained in the PR;
    both build-matrix jobs green (`connect-client` resolves from `google()`).
  - Tile works on Android (opt-in, revocable, reconciled import + summary); hidden when Health
    Connect is unavailable.
  - `screen_nav.dart` sweeps green (the existing "Apple Health connected" surface still passes
    via the `FakeHealthPlatformGateway` override; no Android-specific surface needed since the
    widget is shared).
- **Tests required:** `app/test/health/health_connect_gateway_test.dart` (HC↔wire flow-scale
  mapping + unavailable path — mock the `olf/health` channel like `healthkit_gateway_test.dart`);
  extend `connect_health_flow_test.dart` for the Android gateway path (tile label via the name
  provider, connect flow, denied path); a `dart:io` doc-presence test asserting
  `docs/health-platform-interop.md` exists and carries the Google Fit deprecation note. Real
  Health Connect auth on a device → p0.5-style manual smoke list (no Android device in
  CI/worker env — CI validates the build only).
- **§5 STOP for any wall not covered above:** a `connect-client` version requiring
  `minSdk > 26`; an AGP or Kotlin-plugin version bump; a Gradle dep beyond `connect-client`; any
  permission outside the four-name set. Report, don't work around.

#### p6.4 — Two-way sync + visible sync status
- squash `2db45db` · [PR #69](https://github.com/Abbo0dio/olf/pull/69)
- **Depends on:** p6.2, p6.3
- **Requirement refs:** §2, §3 (retention), §4 (reliability), §9(11)
- **Goal:** move from one-shot import to genuine two-way sync — app-entered data written back to
  the connected platform, imports on a user action ("Sync now") and/or on app open, a per-source
  status surface (connected? last sync? counts? conflicts to review?), and a conflict-review
  screen.
- **Design (orchestrator, 2026-09-05):**
  - **Write-back:** when the user logs/edits flow or BBT and a platform is connected for
    `write`, enqueue a `HealthSample` write (`externalId` round-tripped so a later read matches,
    not dupes). Editing a row whose `source != manual` flips it to `manual` first (the p6.1
    deferral lands here) — the user's value is authoritative and still gets written back.
  - **Sync trigger:** a manual "Sync now" in Apps & export is the baseline; an on-open sync
    (debounced, only if connected, never blocking first frame — reuse the p5.3 lifecycle-timer
    discipline, contained state) is acceptable if it stays cheap. **No background sync, no
    `WorkManager` / BGTask** — new capability, out of scope (backlog note if it comes up).
  - **Status surface:** per connected platform — connected state, last-sync timestamp, last-run
    counts, "N items need review." `reduceSpokenDetail` redacts counts-by-type. Retention: sync
    must not re-import data older than the p2.3 window, and must not write back data the user
    has since purged (purge-before-sync, mirroring purge-before-export).
  - **Conflict-review screen:** lists `ReconciliationPlan.conflicts` — for each, local vs
    incoming, user picks keep local / take incoming / dismiss. Applying is an ordinary repo
    write ("keep local" marks resolved; "take incoming" writes the incoming value as `manual`).
    New `screen_nav.dart` surface; full a11y sweep; dark mode.
  - **threat-model:** update Data flow for the write-back arrows + the retention interaction;
    note the conflict store holds no new data class.
- **Acceptance criteria:**
  - Logging/editing flow or BBT with a platform connected produces a matching platform write
    (verified against `FakeHealthPlatformGateway`), round-trips with no duplicate on the next read.
  - A `source != manual` row, when edited, becomes `manual` and is written back.
  - Status surface shows connected / last-sync / counts / review-count and updates after a sync.
  - Conflict-review resolves each conflict to a deterministic stored outcome; retention window
    respected on both import and write-back.
  - Both new/updated `screen_nav.dart` surfaces pass all five sweeps, no new skips.
- **Tests required:** `app/test/health/write_back_test.dart` (log → platform write; edit
  imported → source flip + write; no-dupe round trip), `app/test/health/sync_status_test.dart`
  (states render; redaction under `reduceSpokenDetail`), `app/test/health/conflict_review_test.dart`
  (each resolution path), a retention-interaction test (purged / out-of-window data not synced).
- **Notes / detail:** worker decides on-open-sync vs manual-only for v1 (propose, note the
  tradeoff). Keep the conflict screen simple — a list + three actions, no bulk ops.
- **Build detail (worker: phase6, folded at close):**
  - **v1 = manual "Sync now" only.** On-open/resume sync deferred (backlog): it needs its own
    `AppLifecycleState` plumbing + debounce + never-block-first-frame guarantee + tests, and the
    design flagged it "acceptable if cheap", not required. Tradeoff noted in the PR: a connected
    user who never opens Settings won't pull platform-side edits until they tap "Sync now".
  - **Write-back** — `app/lib/src/health/health_write_back.dart` (`HealthWriteBack`): after a
    successful local `setFlow` / `setTemp`, read the row back and push it out (`externalId`
    round-tripped, in-window only). Fire-and-forget, connected-gated, errors swallowed
    (`debugPrint`, no PHI); never blocks or fails the log. Wired into `flow_quick_log.dart` +
    `symptom_day_sheet.dart`.
  - **`externalId` sticky on update** (`drift_bbt_repository` / `drift_daily_flow_repository`):
    `setTemp`/`setFlow` with `externalId: null` over a row that already has one keeps the id, so
    an imported-then-edited day stays linked to its platform record — the write-back updates in
    place, no duplicate. `source` still moves to `manual` on a plain edit (the p6.1 deferral).
  - **`ImportReconciler`** — value-already-agrees is now a skip *regardless of source* (was
    `sameValue && sameSource`); absorbs the write-back echo (olf's `manual` row comes back
    platform-attributed, matched by `externalId`, unchanged). Manual-value protection unchanged:
    a *disagreeing* manual row is still always a conflict, never an update.
  - **Status surface** (`settings_page.dart`) — connected · last-sync "N min ago" · added/updated
    counts · a "N differences to review" row → `conflict_review_screen.dart`. `reduceSpokenDetail`
    redacts the counts + the review-row subtitle. `HealthSyncSummary` gained `at`; `encode()` is
    4-field, `decode()` still accepts the pre-p6.4 3-field form. `sync()`/`connect()` return
    `HealthSyncResult { summary, conflicts }` and take a `retentionCutoff`.
  - **Conflict review** — `conflict_review_screen.dart` (new `screen_nav.dart` surface, 5 sweeps
    green): list of `ReconciliationConflict`, each row "your entry" vs the platform + three
    actions (keep mine → write-back · use theirs → `set…` as `manual` · dismiss → drop, reappears
    next sync). No bulk ops. `healthConflictsProvider` — in-memory `NotifierProvider`
    (`// SHORTCUT`: re-derived each sync, lost on restart, Dismiss not persisted).
  - **Retention both directions** — `syncHealthPlatform` / `connectHealthPlatform` run
    `retentionController.sweepNow()` first (purge-before-sync); the cutoff clamps the import
    window *and* filters push-out candidates.
  - No new dep / no schema / no permission / no manifest / no CI change. `threat-model.md`:
    write-back arrow + purge-before-sync note on both data-flow diagrams + a p6.4 Review-log
    entry (conflict store holds no new data class). core 573 / app 426. CI Format bounced once
    (worker's local `dart format` under-reported — `analysis_options.yaml` env bug); fixed in
    `9d3d403`, squashed into `2db45db`.

#### p6.5 — Doctor-ready export (offline PDF report)
- squash `ea585b1` · [PR #70](https://github.com/Abbo0dio/olf/pull/70)
- **Depends on:** p6.1 (data model); independent of p6.2–p6.4
- **Requirement refs:** §2 (data export for doctor visits), §3 (purge-before-export; no PHI in
  filename), §6 (not a medical device — disclaimer on the report)
- **Goal:** one action that produces a clean, clinician-usable report of the user's cycle
  history, symptoms and trends, generated entirely on-device, shareable through the existing
  SAF / file-picker path.
- **Design (orchestrator, 2026-09-05):**
  - **Report document model in `core`** (`core/lib/src/export/clinical_report.dart`) — pure:
    given the user's data + a date range, build a `ClinicalReport` value object (cycle table:
    start / end / length / notable flags; summary stats: mean & range of cycle length, period
    length, variability, the Phase 3 prediction with its humility caveat text; symptom frequency
    table; temperature series for charting; pregnancy / loss events from p1.11; a fixed "not a
    medical device" disclaimer string; generated-on date). Fully unit-tested. No rendering, no
    Flutter.
  - **Rendering in `app`** — **Dependency (§5, pre-approved *pending audit*):** add **`pdf`**
    (pub.dev, DavBfr) — **pure Dart**, generates bytes, no native code, **no `printing`
    companion** (we save/share a file, we don't need the OS print dialog). Claiming PR pastes
    version + transitive subtree + `dependency-audit` result + licence (Apache-2.0). Gate
    identical to p6.2's. Fallback on failure: a hand-rolled minimal single-page PDF, or an HTML
    file the user opens/prints — logged decision.
  - **Share path:** reuse the p1.10 `BackupFileGateway` / file-picker SAF seam — no storage
    permission, user picks the destination. Filename neutral (`olf-report-YYYY-MM-DD.pdf`, no
    name/identifier). **Purge-before-export** (p2.3): the report only includes data inside the
    retention window; if retention excludes part of the requested range, the report says so.
  - **UI:** "Export report for a doctor" in Settings → Apps & export — a range picker (last 3 /
    6 / 12 months / all), a preview of what's included, generate → share sheet. a11y sweep (new
    surface); dark mode for the on-screen preview (the PDF itself is light — fine, it's for
    print); `reduceSpokenDetail` N/A on the button, applies to the preview counts.
  - **threat-model:** log the new user-initiated export egress path — same class as the p1.10
    backup export — note the retention interaction and the neutral filename.
  - **release-checklist:** "generate a doctor report, confirm it opens in a PDF viewer and
    carries the disclaimer" device-check line.
- **Acceptance criteria:**
  - `core` `ClinicalReport` builder, pure, exported; deterministic document for a fixed dataset.
  - App generates a valid PDF (opens in a standard viewer) containing the cycle table, summary
    stats, symptom frequency, a temperature chart, pregnancy / loss events if any, the
    generated-on date, and the "not a medical device" disclaimer.
  - Share goes through the existing SAF seam; filename carries no identifier; data outside the
    retention window is excluded and the exclusion is stated on the report.
  - `dependency-audit` green with `pdf` added; both build-matrix jobs green.
  - New `screen_nav.dart` surface; five sweeps green, no new skips.
- **Tests required:** `core/test/export/clinical_report_test.dart` (structure, stats maths,
  retention-trim, empty-history, disclaimer present), `app/test/export/report_pdf_test.dart`
  (bytes are a valid PDF header + non-trivial size for a seeded dataset; disclaimer text present
  in the content stream), `app/test/export/export_report_flow_test.dart` (widget: range picker,
  preview counts, generate → share invoked with a file), sweeps. Real "opens on a phone /
  prints" → manual smoke list.
- **Notes / detail:** worker owns the report layout and the chart-rendering approach (a simple
  `pdf`-drawn line chart is fine — no charting dep). One document, print-friendly, black-on-white.
- **Build detail (worker: phase6, folded at close):**
  - **`pdf` added** (`^3.12.0`, direct main, Apache-2.0) — all §5 pre-approval conditions met:
    `dependency-audit` green with the full transitive subtree (`archive` MIT, `barcode`
    Apache-2.0, `bidi` MIT, `image` MIT, `path_parsing` MIT, `posix` MIT, `qr` BSD-3), no
    ad/analytics/telemetry; pure Dart, no plugin dir / no `flutter: plugin:` section (`posix` is
    `dart:ffi`-to-libc, no bundled lib); no iOS-target / Android-minSdk bump — both build-matrix
    jobs green; no `printing` companion. APK-size budget green (`Perf budget` job passed).
  - **`core/lib/src/export/clinical_report.dart`** (pure — imports only `meta` + core internals,
    `generatedOn` injected, no `DateTime.now()`): `ClinicalReport` value object +
    `buildClinicalReport(...)`; sub-types `ReportCycle` / `ReportSummary` / `SymptomFrequency` /
    `TemperaturePoint` / `ReportPregnancyEvent`; `clinicalReportDisclaimer` +
    `clinicalReportPredictionCaveat` consts. Retention trim → `includedRange` +
    `retentionExcludedEarlierData` (stated on the report). Regularity via `CycleStats.from` so
    the report agrees with the rest of olf. 12 core tests.
  - **`SymptomRepository.allTypes()`** (+ drift impl) — one-shot read of the whole catalogue,
    **archived included**, so a removed symptom still gets a name on the report; else "Removed
    symptom".
  - **`app/lib/src/export/report_pdf.dart`** — `buildReportPdf(report, {unit, compress})` on
    `pdf`: single A4 doc, black-on-white, built-in Helvetica core font (no bundled asset, no APK
    font hit) — summary table · prediction + caveat · cycle table · symptom-frequency table ·
    hand-drawn (`pw.CustomPaint`) temperature line chart, no charting dep · pregnancy/loss list
    · disclaimer footer. `// SHORTCUT: _ascii()` — a non-Latin symptom name still drops its
    glyphs (with a `pdf` warning); upgrade path = bundle a compact Unicode TTF. English UI,
    print doc — acceptable for v1 (backlog).
  - **`app/lib/src/export/report_providers.dart`** — `reportModelProvider.family` (reactive
    preview) + `ClinicalReportController.generate`: `sweepNow()` (purge-before-export, matches
    p1.10) → build → render → `saveFile`. Filename `olf-report-YYYY-MM-DD.pdf`, no identifier.
  - **`app/lib/src/export/export_report_screen.dart`** — range picker (3 / 6 / 12 months / all),
    live preview (`reduceSpokenDetail` redacts the counts), "Generate report" → share sheet. New
    `screen_nav.dart` surface (20 total), 5 sweeps green.
  - **`BackupFileGateway.writeBackup` → generic `saveFile(bytes, {suggestedName, dialogTitle})`**
    — backup + report share the one SAF / `UIDocumentPicker` seam, neither needs a storage
    permission. One caller updated.
  - **`settings_page.dart`** — the "Apps & export" header + the doctor-report tile now render
    unconditionally; only the health-connect tiles stay gated on `healthAvailable`.
    `release-checklist.md` stale "section is hidden" line fixed.
  - `threat-model.md`: Assets row + Trust-boundary #4 widening + Mitigations + Residual-risks +
    a p6.5 Review-log entry for the new user-initiated **plaintext** export egress path (same
    class as the p1.10 backup — no network, neutral filename, retention-trimmed).
  - No schema / no permission / no manifest / no CI change. `dart format` clean (worker ran it
    pre-push this time). core 586 / app 436.

**Exit gate (Phase 6) — MET (2026-09-06):**
- *Bidirectional Apple HealthKit sync* — **MET: p6.2 #66 `76c31cd`** (read + write, opt-in
  default-off, hand-rolled `olf/health` MethodChannel + Swift `HealthKitBridge`) **+ p6.4 #69
  `2db45db`** (write-back on every log/edit, per-source status surface, conflict review).
- *Bidirectional Android Health Connect sync* — **MET: p6.3 #67 `de46108`** (hand-rolled Kotlin
  bridge on `MainActivity`, same wire contract; `connect-client:1.1.0` Gradle dep, `minSdk`
  24→26, 4 `health.*` perms) **+ p6.4 #69 `2db45db`**.
- *No duplicates / no clobbered user corrections on import* — **MET: p6.1 #65 `ed81ac5`** (pure
  `ImportReconciler` — externalId-then-(type,day) match, a `manual` row is never in `updates`;
  v7 provenance schema `source`/`externalId` + migration + matrix + backup round-trip) **+ p6.4
  #69** conflict-review screen for the disagreements it can't auto-apply.
- *Clinician-usable report, generated offline* — **MET: p6.5 #70 `ea585b1`** (pure `core`
  `ClinicalReport` + on-device `pdf` render, shared via the `BackupFileGateway` SAF seam,
  purge-before-export, "not a medical device" disclaimer, neutral filename).
- *Every platform SDK behind a swappable `core` interface* — **MET: p6.1 #65** —
  `HealthPlatformGateway` + `FakeHealthPlatformGateway` live in `core`; `HealthKitGateway` /
  `HealthConnectGateway` / `UnavailableHealthGateway` are `app/`-only, picked by
  `healthPlatformGatewayProvider` on `defaultTargetPlatform`.

**Phase 6 — phase-wide truths (p6.1–p6.5):**
- **`core` stayed Flutter-free / `DateTime.now()`-free** — the gateway interface, sample model,
  `ImportReconciler` and `ClinicalReport` are all pure Dart; only the platform impls and the PDF
  rendering live in `app`.
- **One schema bump, p6.1: `schemaVersion` 6 → 7** — provenance columns (`source` not-null
  default `manual`, nullable `external_id`) on `daily_flows` + `bbt_entries`; first migration to
  `ALTER` an existing table; shipped with its migration + `migration_matrix_test` to v7 + the
  backup/restore-across-migration round trip in the same PR. No further schema change p6.2–p6.5.
- **Two candidate deps evaluated; one added.** `health` (p6.2/p6.3) was **evaluated and
  rejected** — it forces an SDK-floor bump *and* has no `BASAL_BODY_TEMPERATURE` type (olf's
  primary temperature signal); both platform gateways were hand-rolled instead (p5.4 precedent),
  no pub dep. `pdf` (p6.5) was **added** — Apache-2.0, pure Dart, `dependency-audit` green with
  its 7-package transitive subtree, no SDK-floor bump, no `printing`.
- **New platform capabilities threat-modelled** — HealthKit entitlement + `NSHealth*UsageDescription`
  (p6.2), 4 `android.permission.health.*` + rationale intent-filter (p6.3), the user-initiated
  PDF export egress path (p6.5). `threat_model_doc_test` guard green throughout. Health
  platforms are local IPC — the `OlfHttpClient` TLS chokepoint (p2.6) is N/A, stated in the
  threat model.
- **Opt-in, default-off, revocable** per platform and per direction; the p2.3 retention window
  applies to imported data, written-back data (purge-before-sync) and exported data
  (purge-before-export). No backend, no network anywhere in the phase.

**Deferred to backlog (see `backlog.md`):** on-open/resume sync · delete propagation to the
platform · a persisted (restart-surviving) conflict store · a bundled Unicode font for
non-Latin symptom names in the PDF.

---
