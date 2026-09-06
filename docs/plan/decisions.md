# Decisions log

Append-only. Newest first. Each entry: date, decision, rationale, who/what decided.

- 2026-09-06 — **p8.1a Apple Watch sleeping-wrist temperature stores in `bbt_entries` behind a
  `measurement_kind` column; `schemaVersion` 9→10.** `HKQuantityTypeIdentifier.appleSleepingWristTemperature`
  is a *sleeping wrist* measurement, not a *basal body* temperature. **Rejected** a dedicated
  `wrist_temperature` table: the p6.1 `ImportReconciler` matches by `(type, day)`, so a
  separate table makes a wrist import and a manual BBT day independent and the p8.1a criterion
  "the **unchanged** reconciler conflicts a wrist import against a manual BBT day" becomes
  impossible without touching the reconciler. **Rejected** unmarked reuse of `tempCelsius`:
  `thermalShift` (p7.3), the BBT chart (p1.6), `dailyFertilityScore` (p7.3) and the doctor PDF
  (p6.5) would silently mix sleeping-wrist with basal-body semantics, and the UI can't show
  passive vs typed distinctly. **Approved** option (a): `measurement_kind` `TEXT NOT NULL
  DEFAULT 'basal'` on `bbt_entries` (`enum BbtMeasurementKind { basal, sleepingWrist }`),
  `if (from < 10 && to >= 10) { if (from >= 5) m.addColumn(...) }` (the p6.1 v7 column-add
  precedent). `HealthImportService` reads the bridge value as `HealthSampleType.wristTemperature`,
  re-types to `basalBodyTemperature` only for the `reconcile()` `(type, day)` match, stamps
  `measurementKind: sleepingWrist` on `apply`. **Negotiation condition:** every existing
  `bbt_entries` temperature reader is audited to filter `measurement_kind = 'basal'` so p8.1a
  is a zero-behaviour-change addition; p8.5 is where sleeping-wrist deliberately feeds
  inference. `source_device` (free-form multi-device attribution) is **deferred to p8.2**
  where Oura/Garmin coexist — for p8.1a, `measurement_kind == sleepingWrist` + `source ==
  appleHealth` already uniquely identifies an Apple Watch. HRV/sleep stay declared-but-unmapped
  (each needs a new `HealthSampleType`/`HealthUnit` or an interval-aggregation path — not small)
  → p8.5. Full migration deliverable (g.dart regen, real `schema dump` → `drift_schema_v10`,
  `_dumpedVersions` += 10, `migration_matrix_test` → v10, `wrist_temp_migration_test.dart`,
  backup round-trip) ships in PR #84. — orchestrator, §5 ruling during p8.1a negotiation.

- 2026-09-06 — **p7.6 PMDD daily rating gets a dedicated `pmdd_ratings` table; `schemaVersion` 8→9.**
  A daily multi-symptom rating is a `(date, item, rating)` series — it fits neither p7.5's
  `pain_entries` (one row/day, single intensity) nor the p1.5 presence-only
  `(date, symptomTypeId)` model. **Rejected** ALTER-ing `daily_symptom_entries` with a nullable
  `severity` column: a "rated none today" row breaks the "a row means the symptom happened"
  invariant that the calendar dots, recent-symptoms list and doctor report rely on, and folds
  PMDD's every-day ratings into a table many surfaces read. **Approved** a new additive
  `pmdd_ratings` table (PK `{date, item}`: `item` `textEnum<PmddSymptom>` — a fixed `core` enum,
  no user-configurable rating set in v1 · `rating` `textEnum<SymptomSeverity>` reusing the p7.5
  scale verbatim, with `SymptomSeverity.none` a valid stored value here meaning "rated, nothing
  today" · `createdAt`/`updatedAt`), `if (from < 9) m.createTable(pmddRatings)` — plain additive,
  no `to >=` guard (the v7 column-add precedent doesn't apply to a new table). Shipped **in
  PR #82** on the p6.1 + p7.5 precedent: `.g.dart` regen + real `schema dump` → `drift_schemas/v9`
  + `test/db/generated/schema_v9` + `dump_historical_schemas.dart` `_dumpedVersions` += 9,
  `migration_matrix_test` → v9, new `pmdd_migration_test.dart`, backup round-trip,
  `backup_service` `tableOrder` + `retention_service` `deleteWhere` both += `pmdd_ratings`,
  `docs/local-database.md` "Schema v9" section, threat-model p7.6 entry (new local encrypted
  asset, recomputed overlay never stored, no new egress/permission/CI). The cycle-overlay and
  the luteal-vs-follicular summary reuse `cyclePhaseTimeline` + `cyclePhaseCorrelations`
  unchanged — no DRSP score, no diagnostic threshold (§9(12)). — orchestrator, §5 ruling during
  p7.6 negotiation.
- 2026-09-06 — **p7.5 endometriosis pain/flare log gets a dedicated table; `schemaVersion` 7→8.**
  The p1.5 symptom model is presence-only `(date, symptomTypeId)` and structurally can't hold
  the p7.5 acceptance criteria: an *ordered* intensity scale (synthetic catalogue names like
  "Pelvic pain – severe" aren't rankable, break on rename/archive, and multiply with the region
  tag — and would leave p7.6 with no real reusable scale), a free-text note (no text column near
  the symptom log; dropping the note is itself a §5 stop), and a region tag. Approved a new
  additive `pain_entries` table (PK `date`, one row/day: `intensity` non-null · `region`
  nullable · `note` nullable TEXT · `isFlare` bool · `createdAt`/`updatedAt`) on the p6.1
  precedent — migration + `migration_matrix_test` extension to v8 + new `pain_migration_test.dart`
  + backup round-trip + `drift_schemas/v8` fixture, all in **PR #80**. New pure `core`
  `enum SymptomSeverity` (`.rank`/`.label`) is the reusable ordered scale — **p7.6 rates its
  items on the same enum**. `region` is a fixed `core` `enum PainRegion` (not user-editable).
  Flare↔phase correlation reuses `cyclePhaseCorrelations` unchanged. New asset for the threat
  model: free-text pain notes + structured pain/flare rows in a new local table, SQLCipher-
  encrypted at rest, no new egress/permission/CI gate. — orchestrator, §5 ruling during p7.5
  negotiation.
- 2026-09-05 — **Evaluated the `health` package for p6.2 health-platform interop; rejected.**
  It exposes no `BASAL_BODY_TEMPERATURE` (olf's primary temperature signal) in any version, so
  BBT sync would need a hand-rolled channel regardless; adopting it would additionally force
  iOS deployment target 14→15-equivalent and Android `minSdk` 24→26 and add 6 transitive
  packages, for menstrual-flow sync only. Chose a focused hand-rolled `olf/health`
  `MethodChannel` (flow + BBT) behind the p6.1 `HealthPlatformGateway` interface. Android
  Health Connect (p6.3) hand-rolls its Kotlin half against `androidx.health.connect` — its own
  §5 conversation. — orchestrator, §5 ruling during p6.2.
- 2026-09-05 — **p6.3 Android Health Connect: hand-roll the Kotlin half of `olf/health`;
  add `androidx.health.connect:connect-client` (Gradle) + bump `minSdk` 24→26.** Follows the
  p6.2 rejection of `health` (no `BASAL_BODY_TEMPERATURE`, forces SDK floors, 6 transitive pub
  packages). The Android bridge lives in `MainActivity.kt`, mirrors the Swift `HealthKitBridge`,
  and speaks the identical `olf/health` wire contract so the Dart channel wrapper + codec +
  `HealthImportService` + Settings widget are reused unchanged (the Kotlin side translates
  Health Connect's flow scale to/from the HealthKit wire scale). `connect-client` is a
  first-party AndroidX Gradle dep, **not** a pub package — `pubspec.lock` stays clean — pinned
  to an explicit non-dynamic version and permission-diff-gated by `dependency-audit` (exactly
  `android.permission.health.{READ,WRITE}_{MENSTRUATION,BASAL_BODY_TEMPERATURE}` + the
  `SHOW_PERMISSIONS_RATIONALE` intent-filter, nothing broader). `minSdk` 24→26 *aligns* the
  actual build floor with the already-documented "Android 8+ (API 26+)" minimum — Health Connect
  genuinely requires 26 (this is the floor bump p6.2 avoided because the hand-rolled HealthKit
  bridge did not need it). Google Fit APIs shut down 2026 → Health Connect is the sole Android
  path, no Google Fit integration by design (`docs/health-platform-interop.md`).
  — orchestrator, §5 re-ruling during p6.3.
- 2026-09-04 — **Versioning policy: `1.x.x` is the alpha stage (spans every phase
  until the plan's last phase is `DONE`); `2.0.0` is cut the moment the final
  phase closes, marking the move to beta. Inside `1.x`, a minor bump (`1.Y.0`)
  means new user-facing features shipped since the last release; a patch bump
  (`1.Y.Z`) means bug fixes only, no new features. The version number is chosen
  manually by the Orchestrator for each release — never auto-computed from
  commit count, phase count, or any formula.** Rationale: (1) The product is
  still being built out phase by phase (Phases 0–5 of 13 done as of this entry)
  — calling any of that a "1.0" in the conventional sense would overclaim
  finish; `2.0.0` is reserved as the one meaningful signal that every planned
  phase has shipped and the app has moved from "being built" (alpha) to "built,
  now hardening/polishing in the open" (beta). Post-`2.0.0` versioning (whether
  it continues semver or starts a new scheme) is a future decision, not decided
  here. (2) **Manual, not automatic**, because "new feature vs. bug fix" is a
  judgment call only a human/reviewer can make honestly — a slice can *look*
  small (one file) and still be a feature, or *look* big (a refactor) and still
  be zero user-facing change. The Orchestrator makes the call at release-cut
  time by reading what actually shipped since the last tag. (3) **This
  release, `v1.1.0`** (bumped from `v1.0.1`): a minor bump, not a patch — Phases
  2–5 shipped substantial new user-facing surface (biometric/decoy lock,
  retention/masking + export purge, standalone privacy policy + consent
  switches, TLS-only transport baseline, committed threat model,
  un-waivable dependency-audit release gate, the `AdaptivePredictor` v2
  engine with a visible correction loop, per-category notification channels +
  quiet hours, and all of Phase 5 — WCAG 2.2 AA audit, reduce-spoken-detail +
  auto-lock, caption/transcript type gate, discreet alternate icon, CI
  perf/size budget, migration test matrix) with zero breaking change and zero
  schema change across all of it — a clean minor bump. Also folded into the
  same release-prep commit: the shipped app's display name was `olf_app`
  (the Dart package / Android `applicationId` name leaking into the Android
  `android:label` and the iOS `CFBundleDisplayName`/`CFBundleName`) — fixed to
  the intended `olf` in both `AndroidManifest.xml` (both the main
  `<application>` and the p5.4 `MainActivityBranded` alias — the "Notes"
  decoy-presence alias is deliberately untouched, its whole point is to
  *not* say "olf") and `Info.plist`. The package/namespace identifiers
  (`com.olf.olf_app`, the Dart package name `olf_app`) are internal and
  unaffected — changing those is a different, far more invasive change with no
  user-facing benefit. — orchestrator, with the user's explicit versioning
  scheme (2026-09-04).

- 2026-08-31 — **p2.2 decoy PIN routes to a physically separate, separately-keyed database;
  no schema change, no new deps.** Rationale: (1) **Two vaults, not a filtered view.** A decoy
  session must be unable to *reach or detect* the real data even by a determined coerced user,
  so the decoy is its own `olf-decoy.db` under its own secure-storage key
  (`olf.db.key.decoy.v1`), created lazily on first decoy unlock. `AppVault { real, decoy }`
  selects the (file, key) pair via a new `VaultDatabaseOpener` seam; `appDatabaseProvider`
  watches `appVaultProvider` and keeps exactly one database open — switching closes the other.
  "Its own throwaway store" is then true by construction. (2) **Routing is pure and in `core`.**
  `routePin(pin, {real, decoy}) → PinRoute` (real first, both `verifyPin` run, `null` never
  matches) is unit-tested independently; `PinUnlockScreen._submit` flips the vault and *awaits
  the decoy database* before dropping the lock so the real vault never flashes. (3)
  **Non-detectability is UI-level, per-session.** `AppGate` skips first-run when `vault ==
  decoy`; Settings hides the "Decoy PIN" rows unless `vault == real`; inside a decoy session
  the ordinary lock rows manage the *decoy* credential, and theme/pronoun/biometric prefs come
  from the decoy DB. There is no separate "decoy mode" flag surfaced anywhere. (4) **Bounded by
  a background reset.** The lifecycle listener sets `appVaultProvider` back to `real` on
  pause/hide, so a decoy session can't outlive an app switch and re-entry always re-chooses the
  vault via the PIN. Biometric unlock is always → real. (5) **No schema change / no new deps**
  — reuses SQLCipher + `flutter_secure_storage`; `EncryptedDatabase.open` gained an optional
  `fileName`, the two secure stores gained a `keyName`. Known gaps (→ §9): removing the decoy
  PIN leaves the decoy DB file; no lockout/backoff; DB key still not bound to the PIN. —
  worker: phase2.

- 2026-08-30 — **p2.1 biometric unlock is an opt-in shortcut *past* the PIN, behind a
  `BiometricGateway` seam, with `local_auth` set `biometricOnly: true`; no schema change.**
  Rationale: (1) **Seam, not a direct plugin call.** `local_auth` is a platform-channel plugin
  that throws in `flutter test`, so — exactly like `ReminderScheduler` (p1.7) and
  `BackupFileGateway` (p1.10) — the app depends on an `app`-side `BiometricGateway` interface
  (`canAuthenticate` / `authenticate → success|failed|unavailable`), the production
  `LocalAuthBiometricGateway` wraps the plugin, and `pumpOlf` injects `FakeBiometricGateway`
  (default: incapable, so every pre-p2.1 widget test is untouched). CI never loads the
  channel. (2) **Never a lock on its own.** The switch only shows once a PIN is set; the lock
  screen keeps full PIN entry; a failed/cancelled/unavailable result falls back silently. So
  biometric is purely "is it me?" and the app PIN stays the sole knowledge factor —
  `biometricOnly: true` deliberately refuses the *device* passcode as a stand-in, which keeps
  the model clean for the p2.2 decoy PIN. (3) **No schema change.** One `app_settings` key
  (`SettingKeys.biometricUnlock`, `'true'`/absent) via the p1.6 store; the PIN credential in
  the secure enclave is untouched; drift codegen is byte-identical. (4) **Native config is
  minimal and audited.** Android `MainActivity` → `FlutterFragmentActivity` (a `local_auth`
  requirement); `USE_BIOMETRIC` added to the manifest *with* an `audited:` comment so the
  dependency-audit still passes (38 rules); iOS gets `NSFaceIDUsageDescription`. `local_auth`
  is a Flutter-team, biometric-only package — not on the denylist. (5) **Still a UI-level
  gate** — like the PIN, biometric unlock does not wrap the DB key; binding the key to
  PIN/biometric with a real KDF stays a §9 follow-up. — worker: phase2.

- 2026-08-29 — **p1.11 loss / birth are two `CycleEventType` values on the dormant
  `cycle_events` table (no schema change); the cycle engine marks the interval they fall in as
  a pregnancy gap and the predictor stays silent across it.** Rationale: (1) `cycle_events` has
  been carried since v1 for exactly this; adding `pregnancyLoss` / `birth` enum values is a
  Dart-only change (drift stores the enum name in the existing TEXT column, codegen is
  byte-identical, a v1 DB opens unchanged) — **no `schemaVersion` bump, no migration**. (2) A
  pregnancy is not a cycle: `deriveCycles(periods, {pregnancyEvents})` flags the interval an
  event falls inside as `Cycle.isPregnancyGap`; `CycleStats` then uses only cycles **newer than
  the latest such gap** (`takeWhile`), so pre-pregnancy lengths never contaminate the current
  baseline, and `RobustPredictor` returns **`null` while the open cycle covers the event** —
  no date is projected across a loss / birth. The forecast resumes on its own once a period is
  logged (the thin post-event history makes it low-confidence, then sharpens) — no separate
  "resume" state machine. (3) `PregnancyRecoveryState` (`none` / `awaitingCyclesAfterLoss` /
  `postpartum`) is derived, drives **one** gentle home banner, and is `none` again the moment a
  period starts after the event. (4) Logging lives on its **own Settings screen** (sensitive,
  contained), not the day sheet; copy is "Pregnancy loss" / "Birth", non-clinical, and passes
  the p1.9 inclusive-language lint. (5) Full pregnancy / TTC / postpartum *modes* stay Phase 7
  — this is only the marker + engine handling. — worker: phase1.

- 2026-08-29 — **p1.10 backup is a versioned plaintext JSON document, AES-256-GCM'd under a
  PBKDF2 passphrase, saved through the platform document picker; no schema change; the KDF
  runs on the main isolate.** Rationale: (1) **Serializer separate from crypto.** `core`'s
  `BackupDocument` (`{format, formatVersion, appSchemaVersion, createdAt, tables}`) is
  independently unit-testable for "format is versioned" — `fromJson` rejects a newer version,
  non-int version, wrong `format`; an older version falls through to a forward-migration hook
  (empty for v1). `BackupService.export/import` copies rows **raw** (`SELECT *` → `{col:
  value}` maps; parameterised `INSERT` back) so raw SQLite values — including the integer
  timestamps drift stores for `DateTime` and the string names it stores for enums — round-trip
  byte-for-byte, making "reproduces all data exactly" true by construction. `import` wipes and
  re-inserts every table in **one transaction** (all-or-nothing) and refuses a backup whose
  `appSchemaVersion` differs from the running build. A `tableOrder` constant + a test that
  asserts it equals the live schema means adding a table fails loudly here. (2) **AES-256-GCM
  under PBKDF2-HMAC-SHA256** (210k iterations, stored in the file header so it can rise later)
  via the new `cryptography` package (pure Dart, Dart-ecosystem, **not** ad/analytics —
  denylist is unaffected) added to `core`. A wrong passphrase fails the GCM tag →
  `BackupPassphraseException`, kept distinct from `BackupFormatException` so the UI can say
  "wrong passphrase" vs "not a backup file". Container: `OLFBK1` magic + BE header length +
  public JSON header + ciphertext. (3) **`file_picker`** (added to `app`) for the save/open
  dialogs — it uses SAF / `UIDocumentPicker`, so **no storage permission** and no manifest
  change; confined to `backup_gateway.dart` behind a `BackupFileGateway` interface with a fake,
  exactly like p1.7's notification scheduler, so CI never loads the plugin channel. (4) **No
  schema change / no migration** — backup only reads and writes tables that already exist.
  (5) The KDF runs on the main isolate for now (one-off, explicit user action); moving it to a
  background isolate, gzip before encrypt, and deriving the DB key from the same passphrase are
  §9 follow-ups. — worker: phase1.

- 2026-08-29 — **p1.9 theme + pronoun baseline: no schema change, "golden tests" shipped as
  both-theme render tests, inclusive copy locked in by a source-scanning lint.** Rationale:
  (1) **No schema bump** — `theme_mode` (`system`/`light`/`dark`) and `pronouns` (a `Pronouns`
  enum name; absent → `unspecified` → they/them) are two more `app_settings` keys via
  `SettingKeys`, reusing the p1.6 store. (2) The inline `ThemeData` from `main.dart` is
  extracted to `app/lib/src/theme/olf_theme.dart` as `olfTheme(Brightness)` — same neutral
  sage seed `0xFF4C6B5A` (deliberately not pink), Material 3, one shared `Card`/`AppBar`/text
  baseline so light and dark are consistent; `OlfApp` becomes a `ConsumerWidget` that watches
  `themeModeProvider` and passes `theme` + `darkTheme` + the chosen `themeMode`. (3) The
  acceptance criterion "every screen renders correctly in both themes" is met by
  `app/test/theme/theme_render_test.dart` — each main screen (home, calendar with data, day-log
  sheet, meds, settings, first-run, PIN unlock) pumps under both brightnesses asserting **no
  exception, no `RenderFlex` overflow, and `Theme.of(context).brightness` matches**. **Pixel
  goldens (`matchesGoldenFile`) are deferred** — they need golden CI infra + pinned fonts to
  not be flaky on the ubuntu runner (§9). (4) The pronoun model is pure-Dart
  `core/lib/src/personalization/pronouns.dart` (`formsFor` with `unspecified`→they/them,
  `pronounExampleSentence` as the first live consumer, storage round-trip). (5) Existing copy
  was already second-person / neutral; p1.9 **locks it in** with `docs/inclusive-language.md`
  (human checklist) + `app/test/copy/inclusive_language_test.dart`, which scans every string
  literal under `app/lib` and `core/lib` against a denied-phrase regex list and fails the
  build on a match (bare pronouns are **not** denied — the pronoun feature needs them). —
  worker: phase1.

- 2026-08-29 — **The p1.8 PIN is a UI-level gate, not a cryptographic boundary; no schema
  change; a new `AppGate` root layers first-run → PIN → home.** Rationale: (1) the database is
  already encrypted at rest with a key in the platform secure enclave, so in Phase 1 the PIN
  only decides which screen `AppGate` shows — it does **not** derive or wrap the DB key.
  Binding the key to the PIN with a real KDF, plus biometric unlock / decoy PIN / lockout /
  scheduled deletion / background masking, is Phase 2 (the plan already scoped those out).
  This is stated in `core/lib/src/security/pin.dart` and `docs/privacy-and-lock.md` so nobody
  mistakes it for more than it is. (2) The PIN **secret** is a salted iterated-HMAC-SHA256
  hash (`PinCredential`) in `flutter_secure_storage` — never in the DB, never plaintext;
  **presence of that credential is the "lock is on" signal**, so there is no second flag to
  drift. Work factor is a modest 30k iterations to keep on-device unlock snappy on the main
  isolate — raising it / moving it off-isolate is a §9 follow-up. (3) `crypto` (Dart-team
  package, not ad/analytics) added as a `core` direct dep. (4) The only new persisted bit —
  `onboarding_complete` — reuses the p1.6 `app_settings` store (the §7 p1.6 note anticipated
  this), so **p1.8 has no schema bump and no migration**. (5) Disclaimer copy is four named
  constants in `onboarding/disclaimers.dart` (data on-device / never sold, HIPAA doesn't
  apply, not medical advice, not a contraceptive) so a content test pins them and p1.9's
  language sweep has one target. — worker: phase1.

- 2026-08-29 — **Medications, birth control and the one daily reminder are three additive
  tables at `schemaVersion` 6; the reminder stores no free text, and the notification plugin
  sits behind a `ReminderScheduler` interface (p1.7).** New tables: `medications(id, name,
  dosage?, notes?, archived_at?, created_at, updated_at)` — a soft-archived list, name
  validated, mirroring `symptom_types`; `birth_control_entries(id, method, started_on,
  ended_on?, notes?, created_at, updated_at)` — a *history*, `ended_on IS NULL` = current, and
  `switchTo` closes the previous open row so a method change can later be lined up against
  symptoms; `reminders(id, kind UNIQUE, hour, minute, enabled, created_at, updated_at)` — a
  table (not an `app_settings` key) so Phase 4's granular system extends it, but p1.7 keeps
  exactly one row. Rationale: (1) **no free-text column on `reminders`** — the notification
  title/body are fixed generic constants in `app/lib/src/reminders/reminder_scheduler.dart`
  (`'olf'` / `'Time for your daily check-in.'`), so no medication name, dosage or method can
  reach a lock screen; the acceptance criterion "reminder text contains no health details" is a
  compile-time fact, asserted in `reminder_controller_test.dart`. (2) The **pure schedule
  model** (`ReminderSchedule` + `nextOccurrence` + `validateReminderTime`) lives in `core`;
  the OS wrapper (`flutter_local_notifications`) is confined to one app file behind an
  interface with a fake, so widget tests never load a platform channel and Phase 4 can widen
  the wrapper without touching `core`. (3) New app deps `flutter_local_notifications` +
  `timezone` + `flutter_timezone` — none are ad/analytics/crash SDKs, none are denylisted; the
  reminder is *inexact* (`AndroidScheduleMode.inexactAllowWhileIdle`) so it needs **no
  exact-alarm permission**; the two app-manifest permissions (`POST_NOTIFICATIONS`,
  `RECEIVE_BOOT_COMPLETED`) each carry an `audited:` comment. (4) Birth control is a history,
  not a single value, for the same reason symptoms are dated — a later phase correlates.
  — worker: phase1.
- 2026-08-29 — **BBT is stored in Celsius; mucus is a Billings enum; both are day-keyed tables,
  and mucus feeds the fertile window only at the display layer (p1.6).** `schemaVersion` bumped
  to **5**: `bbt_entries(date PK, temp_celsius REAL, created_at, updated_at)`,
  `cervical_mucus_entries(date PK, type TEXT, created_at, updated_at)`, and a general
  `app_settings(key PK, value, updated_at)` key/value store. Rationale: (1) storing temperature
  **canonically in °C** and treating °C/°F as a display preference keeps one number in the DB
  and all rounding in one file — the alternative (store-as-entered) makes every read
  unit-aware. (2) `CervicalMucusType { dry, sticky, creamy, watery, eggWhite }` is a small
  fixed ordered scale, not a user vocabulary, so it's an enum column, not a catalogue like
  symptoms. (3) A generic `app_settings` table (rather than a bespoke column) is the reusable
  home for the unit choice and for p1.8's PIN-enabled flag / p1.9's theme + pronoun. (4) The
  p1.4 acceptance "mucus feeds the fertile-window display" is met with a **display-layer merge**
  (`observedFertileWindow(...)` → an extra "Fertile signs (from your notes)" line) rather than
  by changing `RobustPredictor` or `CyclePrediction` — the `Predictor` seam stays pristine for
  Phase 3's swap, and `p1.4`'s tests are untouched. BBT and mucus are day-keyed and unlinked
  from `periods`, exactly like `daily_flows`. The per-cycle BBT chart is a self-contained
  `CustomPaint` — no charting package, so the dependency denylist surface doesn't grow.
  — worker: phase1.
- 2026-08-29 — **Symptoms are a user-editable catalogue + per-(day, type) presence rows
  (p1.5).** `schemaVersion` bumped to **4**: `symptom_types(id, name, sort_order, is_built_in,
  archived_at?, created_at, updated_at)` is the vocabulary; `daily_symptom_entries(date,
  symptom_type_id → symptom_types ON DELETE CASCADE, created_at, PRIMARY KEY(date,
  symptom_type_id))` is the log. Rationale: a catalogue table (not a fixed enum) is what makes
  "add / rename / reorder your own symptoms" a data change rather than a code change; a
  composite-key presence row makes multi-select logging idempotent (toggle = insert-or-ignore /
  delete) with nothing to validate, so day logging is plain CRUD while the catalogue carries
  the validation (`validateSymptomName`: empty / >40 / case-insensitive duplicate among active
  names). **Removal is a soft archive** (`archived_at`), not a delete: a removed symptom leaves
  the pickers but its historical entries stay meaningful and its name is never silently reused.
  The ~11 built-in names are gender-neutral and seeded by `_seedBuiltInSymptoms()` from **both**
  `onCreate` and the `from < 4` upgrade, so fresh and upgraded databases are identical. Entries
  are **presence-only in v1** — no severity/scale; mood & energy are modelled as ordinary
  toggle symptoms, not sliders. Entries are unlinked from `periods` (same reasoning as
  `daily_flows`). On the calendar, tapping a **non-period** day now opens the symptom day sheet
  (a period day still opens the flow sheet, which gains an "Add symptoms" button); the sheet
  offers "Start a period" so p1.1's tap-an-empty-day affordance survives. — worker: phase1.
- 2026-08-28 — **Prediction v1 is a stats-based `RobustPredictor` behind a `Predictor` seam
  (p1.4).** `Predictor.predict({cycles, today}) → CyclePrediction?` in `core`; Phase 3's
  adaptive/backtested engine replaces the implementation with no call site change. **No schema
  change** — the forecast derives from `cyclesProvider` on every read, so editing history
  recomputes it on the same screen. v1 maths: anchor on the **last logged period start**,
  project the median recent (≤ 12, non-gap) cycle length, widen to `[anchor + shortest,
  anchor + longest]` with a ±1-day floor so a date is never claimed to the day. Fertile window
  = `expected − 14` (luteal phase treated as a fixed 14 days for v1) ± sperm/ovum viability
  → a 7-day `DateRange`. **A late period never rolls the estimate forward**: `expected` depends
  only on the anchor, and once `today` passes the window the status is `overdue` and the UI
  shows a "Period check-in" ("N days later than usual" + a *Log period start* button), not a
  new future date. Confidence is a coarse three-bucket hint (`high` = regular + ≥ 3 cycles;
  `medium` = regular/mostly-regular + ≥ 2; else `low`; any likely gap → `low`). Rationale:
  ships the headline differentiator as *correct, humble, correctable* now without pretending
  to Phase 3's accuracy; every date is a range with an uncertainty note; the seam keeps the
  swap cheap. Raw min/max (not percentiles), point-anchored fertile window, and the fixed
  luteal length are follow-ups in §9. — worker: phase1.
- 2026-08-28 — **Cycles are derived on read, never stored (p1.3).** `core/lib/src/cycle/`
  turns the `periods` list into `List<Cycle>` (start-to-start pairing; newest period opens the
  current cycle) plus a `CycleStats` summary — median cycle / period length, min–max range, a
  coarse `CycleRegularity` (spread-based: ≤ 4 / ≤ 9 / more), and a `hasLikelyGap` flag for
  intervals over **45** days that more likely mean a missed entry. **No schema change** in
  p1.3. Rationale: derived data stored is derived data that can go stale or need its own
  migration; recomputing off `periods` on every change keeps "editing history changes the
  numbers" true for free and matches p1.1's no-forward-cascade rule. **No 28-day (or any)
  default anywhere** — with too little history every figure is `null` and the UI asks for more
  logging. Regularity thresholds and the gap cutoff are heuristics flagged for revisit in §9.
  — worker: phase1.
- 2026-08-28 — **Per-day flow is its own table, unlinked from `periods` (p1.2).** Schema
  `schemaVersion` bumped to **3**: new `daily_flows(date PK, intensity, clot_size?, created_at,
  updated_at)` — one row per calendar day, keyed by the date itself (no autoinc id, no FK to
  `periods`). Rationale: flow is an observation about a *day*, not about a period row; keeping
  them unlinked means editing or deleting a period never cascades onto what was logged, and the
  same day can carry flow whether or not a period is recorded for it. `setFlow` upserts on
  `date` and preserves `created_at` (a correction is auditable). No validation — any intensity
  is valid and clots are optional — so `DailyFlowRepository` is plain CRUD; the UI decides when
  to offer logging (period days + today). Migration `from < 3` is purely additive. No new
  dependencies. **Interaction change from p1.1:** tapping a period day on the calendar now
  opens the flow quick-log sheet (the §4 fast path) instead of the period-dates editor; the
  sheet's "Edit period dates" button and the "Add a period" button preserve p1.1's editor
  entry points. — worker: phase1.
- 2026-08-28 — **Periods are a dedicated interval table, not paired events (p1.1).** Schema
  `schemaVersion` bumped to **2**: new `periods(id, start_date, end_date?, created_at,
  updated_at)`. `cycle_events` stays as the point-in-time event log for p1.11 (loss / birth /
  postpartum). Rationale: overlap checking, editing and deletion are natural on an interval
  row and awkward on paired start/end events. The overlap / impossible-range invariant is
  enforced in `PeriodRepository` (`addPeriod` / `updatePeriod` throw
  `PeriodValidationException`), **not** by DB constraints, so one rule covers every screen and
  stays unit-testable; "today" is an injected clock so it is deterministic and offline.
  `CycleEventRepository` is retained in `core` but unused by the app. No new dependencies —
  the month calendar is a hand-rolled grid. — worker: phase1.
- 2026-08-28 — **Local store realised (p0.4):** `drift` over SQLCipher
  (`sqlcipher_flutter_libs`), key in `flutter_secure_storage`, **Riverpod** for state — all
  three per the §3 provisional table, now committed. Schema + queries + migrations live in
  `core`; the encrypted `QueryExecutor` and key store are injected from `app` so `core` stays
  Flutter/SQLCipher-free (protects Phase 13). drift codegen output is committed and diff-checked
  in CI. — worker: phase0.
- 2026-08-27 — **`CI OK` is a required status check** on the `protect-main` ruleset (p0.3);
  `strict_required_status_checks_policy: false`. A PR now cannot merge unless
  format/analyze/test/dependency-audit/build all pass. — worker: phase0.
- 2026-08-27 — **`pubspec.lock` is committed** for every package (`core` + `app`), overriding
  the usual "libraries don't commit their lock" convention (p0.3). Rationale: the
  dependency-audit gate scans the locked transitive graph statically (no resolution step, no
  drift), and pinned resolutions keep CI reproducible. The audit job still runs `pub get` and
  fails on lock drift so the committed lock cannot go stale. — worker: phase0.
- 2026-08-27 — Monorepo wiring is **plain `path:` dependencies, not Melos** (p0.2). Two
  packages (`core`, `app`); `app` depends on `core` via `path: ../core`. Rationale: two
  packages do not justify Melos's bootstrap step and extra dev-dependency; per-package
  `dart`/`flutter` commands in CI are explicit and readable, and running `core` with plain
  `dart` (no Flutter tooling) actively enforces the "`core` has no Flutter dependency" rule.
  Revisit if the package count grows (e.g. a desktop shell package in Phase 13). — worker: phase0.
- 2026-08-27 — Toolchain pinned via **`mise`** (`mise.toml` at repo root): Flutter **3.35.5**
  / Dart **3.9.2** (p0.1/p0.2). CI pins the same through `FLUTTER_VERSION` in `ci.yml`. This
  confirms the §3 provisional Flutter choice for the MVP; no change to it. — worker: phase0.
- 2026-08-27 — Framework provisionally **Flutter**; architecture is a pure-Dart `core` package
  plus a Flutter `app`, with a future desktop app as a *separate* lean shell reusing `core`.
  Rationale: one codebase for iOS+Android, native-compiled so it runs on low-end devices,
  nothing phones home by default (no-analytics rule), desktop path available without bloating
  mobile. — initial plan author.
- 2026-08-27 — MVP is **fully on-device, no backend**; encrypted sync deferred to Phase 9.
  Rationale: local-first principle, smallest early attack surface. — initial plan author.

---
