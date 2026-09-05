# Backlog / unscheduled

Ideas and follow-ups not yet placed in a phase. Add freely; groom into phases later.

- ~~**Phase 0 exit-gate: device smoke + `integration_test` in CI.**~~ **Closed → p0.5.**
  `.github/workflows/nightly-integration.yml` runs `flutter test integration_test/` on an
  Android emulator (API 34) and an iOS simulator nightly + on demand — deliberately a
  separate, non-blocking workflow, not a PR gate (emulator boots are slow/flaky; the restart
  round-trip is covered headless on every PR). API 26 was tried and dropped (image won't boot
  reliably on GitHub runners). One-time manual install+launch on a physical Android + iOS
  device remains open — see the p0.5 table in Phase 0.
- **p0.4 follow-ups still open:** move `EncryptedDatabase` open to a background isolate if
  first-frame jank appears; revisit the DB directory choice when p1.10 (backup/export) lands.
- **Adopt `drift_dev schema` snapshot tooling** for the next migration. The p1.1 v1→v2
  migration test (`core/test/db/period_migration_test.dart`) hand-builds the old schema; the
  snapshot generator would let each future upgrade be tested step-by-step from a dumped
  schema. (Was a p0.4 follow-up; deferred again — a hand-rolled test was enough for three
  small additive migrations, v1→v2, v2→v3 and v3→v4.) — noted by worker: phase1 during p1.1,
  still open after p1.5.
- **p1.1 follow-ups:** period-length sanity ceiling (a `tooLong` validation error, e.g. warn
  past ~15 days) — deliberately left out of p1.1, which blocks only overlaps and impossible
  ranges; a one-tap "period ended today" quick action from the home summary (the editor
  already supports adding an end date). — noted by worker: phase1.
- **p1.2 follow-ups:** flow is loggable only on period days + today (the calendar tap opens the
  period editor on any non-period day). A "log flow for an arbitrary past day without a period"
  entry point (spotting between periods) is not yet designed — revisit alongside p1.11 events
  or a dedicated symptom-logging slice. The `daily_flows` row has no "notes"/free-text field;
  add if a later slice needs it. — noted by worker: phase1 during p1.2.
- **p1.3 follow-ups:** the `CycleStats` regularity thresholds (spread ≤ 4 `regular`, ≤ 9
  `mostlyRegular`) and the 45-day likely-gap cutoff are heuristics chosen from typical ranges,
  not tuned against data — revisit once p1.4's predictor and real histories exist (they may
  want to share one definition of "irregular"). Also: the history list is still period-first;
  a dedicated per-cycle detail view (this cycle's flow, symptoms, length vs. your typical) is
  later work. And `deriveCycles` treats every gap as a single long cycle plus a flag — it does
  not try to *infer* how many cycles were missed. — noted by worker: phase1 during p1.3.
- **p1.4 follow-ups (feed Phase 3):** `RobustPredictor`'s next-period window is the raw recent
  min/max around the median — no percentile/MAD trimming, so one outlier cycle widens it a lot.
  The fertile window is anchored on the point estimate only (not widened by the next-period
  uncertainty) and assumes a **fixed 14-day luteal phase** — p1.6's BBT / cervical-mucus inputs
  should refine ovulation timing rather than this constant. Confidence is a 3-bucket hint with
  hand-picked thresholds; no backtesting / calibration yet. `predictionProvider` reads
  `DateTime.now()` directly (fine for v1; a `clockProvider` would make the late-state widget
  test time-independent). — noted by worker: phase1 during p1.4.
- **p1.5 follow-ups:** symptom entries are **presence-only** — no per-entry severity/scale, and
  no free-text note per day; add a severity column (or a notes field) if a later slice needs
  it. Mood & energy are plain toggle symptoms, not ordered scales — a dedicated scale widget is
  deferred. The "Recent symptoms" list resolves names against the **active** catalogue only, so
  a day that has an archived symptom still counts on the calendar but that symptom's name drops
  out of the list; a history view that resolves archived names (or a per-cycle "this cycle's
  symptoms" rollup in `_History`) is later work. Cervical-mucus / discharge is a single toggle
  symptom here — the structured Billings-style classification that feeds the fertile window is
  **p1.6**. `reorderTypes` rewrites every `sort_order` on each drag (fine at this scale; a
  sparse/fractional index would avoid the rewrite). No cap on the number of custom symptoms.
  — noted by worker: phase1 during p1.5.
- **p1.6 follow-ups:** `observedFertileWindow` is a crude signal — it just brackets the
  fertile-quality mucus days plus one; it does not detect a "peak day" / drop-off, cross-check
  against the BBT thermal shift, or narrow the statistical estimate (it only shows alongside
  it). The BBT chart has **no coverline / thermal-shift detection** and no smoothing — it is a
  plain plot; a proper biphasic-shift marker and a fertile-window derived from BBT+mucus
  together is Phase 3 territory (and would let `lutealPhaseDays` stop being a fixed 14). No
  outlier rejection on BBT points (a disturbed-sleep reading skews the line). `temp_celsius`
  has no DB `CHECK` — plausibility is repository-only, so a raw SQL insert could store nonsense.
  Only one reading per day (no "took it twice" reconciliation). The °C/°F choice lives in
  `app_settings` but there is no Settings screen yet — it is only reachable via the temperature
  dialog's toggle; a real settings surface is p1.8/p1.9. Mucus is a single daily observation
  (no sensation vs. appearance split, no "checked, saw nothing" vs. "didn't check").
  — noted by worker: phase1 during p1.6.
- **p1.7 follow-ups:** the daily reminder is **inexact** (`inexactAllowWhileIdle`) — the OS may
  fire it minutes late and it deliberately does not request `SCHEDULE_EXACT_ALARM`; a
  minute-accurate option is Phase 4. Only **one** reminder, one time a day, one `ReminderKind`
  — no per-medication reminders, no "twice daily", no snooze, no day-of-week filter (all Phase
  4, which the `reminders` table is shaped for). Local-timezone resolution falls back to **UTC**
  if `flutter_timezone` fails, so a reminder could be off by the UTC offset on an
  unusual device; there is no re-anchor on a travel/DST change beyond what
  `matchDateTimeComponents: DateTimeComponents.time` gives. Tapping the notification just opens
  the app — no deep link to the meds screen. `hour`/`minute` have no DB `CHECK` (repository-only
  validation, like `temp_celsius`). Birth control: no reminder tie-in (e.g. "pill at 9pm"), no
  pack/placebo tracking, no injection-due-date maths; the method history is recorded but nothing
  reads it yet. Medications: a plain list — no schedule, no per-dose log, no interaction/refill
  data, no reminder per medication. The meds screen is reachable only from a home AppBar icon;
  a real Settings hub is p1.8/p1.9. The `ReminderScheduler` real path (`zonedSchedule` firing
  on a device) is exercised only manually / on-device — the CI coverage is the wrapper contract
  test with a fake, per the task's "test around the notification scheduling wrapper".
  — noted by worker: phase1 during p1.7.
- **p1.8 follow-ups (mostly Phase 2 by design):** the PIN is a screen gate only — it does not
  wrap the SQLCipher key, so someone with the unlocked device / a file dump still gets the DB
  via the enclave key. No **biometric** unlock, no **decoy PIN** + decoy dataset, no
  **failed-attempt lockout / backoff** (unlimited guesses), no **scheduled auto-deletion**, no
  **screenshot / app-switcher masking** (§3 "blur when backgrounded" — only re-lock-on-pause
  is done). PIN hashing (iterated HMAC-SHA256, 30k) runs on the **main isolate** (~150 ms
  desktop, more on a phone) and the work factor is deliberately low for responsiveness — Phase
  2 should move it to a background isolate and/or use a real KDF that also derives the DB key.
  `PinCredential` has no versioned re-hash path if the work factor changes later. The
  re-lock-on-background timing has no grace period (instant re-lock even on a quick app
  switch). The first-run screen has no "why does this matter" deep-dive or links, and no
  language toggle. `SettingsPage` currently holds only the app lock; export/import (p1.10) and
  theme/pronoun (p1.9) join it there. — noted by worker: phase1 during p1.8.
- **p1.9 follow-ups:** **pixel goldens are deferred** — the both-theme render tests assert "no
  exception / no overflow / brightness matches" but not exact pixels; a real
  `matchesGoldenFile` suite needs golden CI infra + a pinned font so it is not flaky on the
  ubuntu runner (candidate for a Phase 2/5 polish slice). Only **one live consumer** of the
  pronoun setting (`pronounExampleSentence` in Settings) — no screen copy is actually
  personalised yet; wiring `formsFor` into real strings (prediction card, reminders, day sheet)
  is future work, and doing so needs those strings to move off plain literals, which the
  inclusive-language lint currently assumes. The lint is **literal-only** — it cannot see
  copy assembled by interpolation/concatenation from non-literal parts, asset text, or store
  listings. `themeMode` is app-wide only — no per-screen or scheduled (e.g. sunset) dark mode,
  and no true-black OLED variant. No in-app font-scale / high-contrast / reduce-motion controls
  (rely on OS settings for now). The theme is a single seed colour — no user theme/accent
  choice. — noted by worker: phase1 during p1.9.
- **p1.10 follow-ups:** the PBKDF2 KDF (210k iterations) runs on the **main isolate** — a
  one-off explicit action, but a large database on a slow phone could jank for a second or two;
  move it to a background isolate (and consider Argon2id). The JSON document is **not
  compressed** before encryption — fine at Phase 1 data volumes, add gzip when history grows.
  Backup and the DB-at-rest key are **independent secrets** (backup passphrase vs. the enclave
  key); a future revision could derive both from one passphrase. **No integrity of the backup
  set** — nothing tracks how many backups exist or where. p2.3 makes every backup written
  *after* a window is set exclude purged data (purge-before-export), but scheduled
  auto-deletion still does **not** reach `.olfbackup` files already saved to disk (§9(11) /
  requirements "delete means delete") — see the p2.3 follow-up. Restore is **whole-database replace only** — no merge, no selective import, no
  "preview before restoring", and it hard-refuses a backup from a different `schemaVersion`
  rather than migrating it (so a backup taken now cannot be restored after the next schema
  bump until a format migration is written). The real `file_picker` SAF/UIDocumentPicker path
  is manual/on-device only in CI (the `BackupFileGateway` fake covers the seam), like p1.7's
  scheduler. `.olfbackup` is not registered as an app file type, so "open with olf" from a
  file manager does nothing. No auto/periodic backup, no cloud target. — noted by worker:
  phase1 during p1.10.
- **p1.11 follow-ups:** a loss / birth is only loggable from **Settings → Cycle** — there is no
  affordance to record one on a tapped calendar day, and the event day is **not drawn** on the
  month calendar. `PregnancyRecoveryState` flips straight to `none` on the first post-event
  period rather than easing the forecast back over a few cycles (the predictor's own
  low-confidence ramp is the only softening). No pregnancy / TTC / postpartum **modes**, no
  due-date / gestational-age tracking, no tailored postpartum symptom set — all Phase 7. Banner
  copy is fixed and not pronoun-personalised (the p1.9 infra exists but isn't wired here).
  Multiple losses / births are stored, but only the **most recent** drives the banner and the
  stats reset. `deriveCycles` treats an event dated exactly on a period-start day as belonging
  to no interval (documented + tested), so a same-day "loss, then period resumes" needs the
  period dated at least a day later for the stats to reset. — noted by worker: phase1 during
  p1.11.
- **p2.1 follow-ups:** biometric unlock is still a **UI-level gate** — it does not derive or
  wrap the SQLCipher key (same limitation as the PIN); binding the DB key to the PIN/biometric
  with a real KDF, and moving the PIN hash off the main isolate + raising its work factor,
  stay open (carried from p1.8). No **failed-attempt lockout / backoff** on either the PIN or
  the biometric retry button — that is p2.4-adjacent hardening. The auto-prompt fires once per
  lock-screen mount; it does **not** re-fire if the user backgrounds and returns while still on
  the lock screen (they use the "Use biometrics" button). `biometricOnly: true` means devices
  with only a passcode (no enrolled fingerprint/face) can't use the shortcut by design —
  revisit if users ask for device-credential fallback. The real `LocalAuthBiometricGateway` is
  not unit-tested (glue over a channel), matching the p1.7 precedent; a device/integration
  test could be added to the nightly. — noted by worker: phase2 during p2.1.
- **p2.2 follow-ups:** (a) turning the decoy PIN **off** leaves `olf-decoy.db` on disk — it is
  just unreachable; a real "delete the decoy space" action (and wiping it) is open. (b) The
  decoy vault opens with **default preferences** (system theme, they/them, biometric off) —
  an owner who runs a heavily-customised real app might notice the difference; seeding the
  decoy DB with a copy of a few innocuous prefs on creation would close that. (c) No
  **failed-attempt lockout / backoff** still (shared with p2.1). (d) The DB key is still not
  bound to the PIN — each vault's SQLCipher key sits in secure storage independent of its PIN,
  so an attacker with a secure-store dump + the decoy PIN still can't read the real DB, but an
  attacker with the real key doesn't need any PIN. Binding each vault's key to its PIN with a
  real KDF is the p1.8/p2.1 carry-over. (e) `_submit` awaits `appDatabaseProvider.future`
  after switching vault; if the decoy DB fails to open the user lands on the fail-safe screen
  rather than the lock screen — acceptable but not graceful. (f) The decoy DB is created on
  first decoy unlock, so the very first duress use has a brief "opening database" spinner the
  real vault wouldn't show on a warm start. — noted by worker: phase2 during p2.2.
- **p2.3 follow-ups:** (a) **§9(11) — already-saved backups are not scrubbed.** Scheduled
  auto-deletion purges the live DB and every *new* export, but the app keeps no registry of
  where past `.olfbackup` files were saved (the `BackupFileGateway` just streams bytes to an
  OS save dialog), so it cannot retroactively open and rewrite them. Options for a later
  slice: a "known backups" list the app maintains + a "re-scrub my backups" action, or making
  restore itself apply the current window on import. (b) **No background/periodic sweep** —
  the purge runs on app launch (past the lock), on window change, and before an export; an
  app left open for days past a cutoff boundary won't purge until the next launch/export.
  A `WorkManager`/`BGTaskScheduler` periodic job is Phase 4-adjacent. (c) **Coarse windows
  only** (6 months / 1–3 years) — no custom "keep N days" or per-data-type retention. (d)
  **Hard delete, no undo** — there is no trash/grace period; the confirmation dialog is the
  only safety net. (e) The startup sweep runs **on every launch** when a window is set (it's
  cheap — indexed `DELETE`s, usually zero rows — but it is not throttled to "once a day").
  (f) `RetentionService.sweep` takes `now` from the caller (`DateTime.now()` in
  `RetentionController`); a `clockProvider` would make the widget test fully time-independent
  (shared with the p1.4 follow-up). — noted by worker: phase2 during p2.3.
- **p2.4 follow-ups:** (a) **All-or-nothing.** `FLAG_SECURE` and the app-switcher mask are
  held for the whole app lifetime — there is no per-screen scoping (e.g. allow a screenshot
  of an empty calendar but not the day sheet) and no user opt-out for someone who wants to
  screenshot a chart for a clinician. A `SecureScreen` marker widget + a ref-counted
  controller is the shape if this is wanted. (b) **iOS screenshots/recordings are not
  blocked** — there is no OS API; only the app-switcher snapshot is covered (natively in
  `AppDelegate` + the Flutter shield). iOS `UIScreen.isCaptured` screen-recording *detection*
  (show the mask while recording) is a possible add. (c) The native pieces
  (`MainActivity.kt` FLAG_SECURE handler, `AppDelegate` cover) are **compile-checked by the
  `build` CI job only** — no device/integration test, matching the p1.7 / p2.1 precedent for
  channel glue; the nightly `integration_test` job could gain a lifecycle-mask check. (d) The
  mask shows on *every* non-`resumed` transition including a brief Control-Centre pull-down —
  intentional (fail-safe) but a short debounce could reduce the flicker; not worth it yet. (e) The
  cover is a plain themed panel; a deliberate branded splash would look less like a glitch.
  — noted by worker: phase2 during p2.4.
- **p2.5 follow-ups:** (a) The two consent switches (`analytics_opt_in`, `data_sharing_opt_in`)
  are **forward-looking gates with no consumer yet** — nothing in the app reads them, because
  the app collects and shares nothing. Whichever future slice adds a metric or a share must
  check the relevant provider *and* add its specifics to the "What we would ever collect"
  policy section (there is no test binding the two together yet). (b) The policy is **English
  only** and the "last reviewed" date is a hand-maintained constant
  (`privacyPolicyLastUpdated`) — a copy change that forgets to bump it only trips the
  "four-digit year" check, not staleness. (c) No **acceptance/version tracking** — the user
  is never asked to acknowledge a policy change (by design: "continued use never counts as
  agreement", and any new practice is opt-in), but if a jurisdiction ever requires explicit
  re-consent this needs a stored policy-version key. (d) The MHMDA/SB370 alignment is a
  good-faith reading, **not a lawyer review**. (e) Educational explainers (HIPAA gap,
  law-enforcement reality, delete walkthrough) are deliberately **out of scope → p2.7**.
  — noted by worker: phase2 during p2.5.
- **p2.6 follow-ups:** (a) **Certificate pinning is designed, not enforced.** `OlfHttpClient
  .certificatePins` is an empty map and `_checkPins` *throws* for any host added to it — so
  the first slice that adds a real backend host must implement enforcement (a `SecurityContext`
  trusting only the pinned chain, or a leaf-SPKI check in a `connectionFactory` /
  post-connect) and add the matching `<pin-set>` to the Android config. `dart:io` has no
  built-in SPKI-pinning helper; if a small audited package is cleaner at that point, add it
  **then** — it is not pulled in speculatively now (ponytail). (b) The `OlfHttpClient` seam
  lives in `app/` because all near-term network features are app-side; if a **core**-side
  feature (e.g. a sync engine) needs it, the ~1-file seam moves to `core/lib/src/net/`
  (it is pure `dart:io`, no Flutter). (c) The source-bypass scan
  (`app/test/net/transport_security_test.dart`) is **substring/regex based** — it catches
  `HttpClient` / `package:http` / raw `Socket`, but a determined bypass via reflection or a
  transitively-added client isn't caught; the denylist gate is the backstop for the latter.
  (d) No **runtime** proof that cleartext is blocked on-device — the checks are static
  (config scan + seam unit test); a nightly `integration_test` that asserts an `http://`
  request throws could be added. (e) `usesCleartextTraffic="false"` in the main manifest is
  assumed not to break `flutter run` hot-reload on current Flutter (it does not — the VM
  service uses `adb forward` / localhost, not the cleartext-guarded APIs); revisit if a dev
  reports otherwise. — noted by worker: phase2 during p2.6.
- **p2.7 follow-ups:** (a) The explainers are **English only** and are static `const` copy —
  no "last reviewed" marker, so a legal-landscape change (e.g. a new state consumer-health
  law, or an actual federal one) has to be caught by hand. (b) The content is **not a lawyer
  review** — same good-faith-reading caveat as the p2.5 policy; the HIPAA and
  law-enforcement explainers make legal-adjacent claims. (c) The delete explainer **describes**
  uninstall but can't perform it — there is no in-app "wipe everything now" button (uninstall
  is the OS's job); a `core`-side "delete all data" action that clears the vault + secure
  storage without uninstalling is a possible add for people who want to stay installed. (d)
  The "~9% take a protective action" framing is addressed only by the Backup & restore
  hand-off; there is no measurement (and won't be — no analytics) of whether users reach or
  act on these screens. (e) The tone check is a **fixed denylist** of alarmist words, not a
  readability or reading-level check. — noted by worker: phase2 during p2.7.
- **p2.9 follow-ups:** (a) **`ci.yml` itself is still editable in a PR.** The wiring-lock test
  makes weakening the audit *visible* (it fails the `test` job) but a reviewer could still
  approve a PR that changes both the workflow and the test together. On a solo repo the
  release-checklist self-review is the backstop; a CODEOWNERS rule on `.github/` +
  `dependency-denylist.txt` requiring a second approver is the real fix once there is a
  second maintainer. (b) **The audit still only sees pub packages.** Native Gradle/CocoaPods
  SDKs added directly are not in `pubspec.lock`; the threat model (p2.8) and the release
  checklist call this out but there is no mechanical gate (candidate: parse
  `settings.gradle` / `Podfile.lock` if native deps are ever added). (c) **"Security
  reviewer" is a role with one holder.** The escalation path is documented but not enforced
  by tooling — it relies on the maintainer following it. (d) The `jq` dependency in `ci-ok`
  is fine on `ubuntu-latest` (preinstalled) but is a new assumption vs. the previous
  `grep`-only step. — noted by worker: phase2 during p2.9.
- **p3.4 follow-up — `AdaptivePredictor` interval-width discontinuity:** adding a cycle
  that flips the drift detector on/off can jump the predicted **range width** (a ~56-day
  tail in `adaptive_predictor_property_test`). The p3.4 anti-snowball work stabilised the
  *point* estimate (a single outlier now moves it ≤ 2 days) but not the interval recompute
  — that needs a drift-strength ramp applied to the *interval*, not just the centre.
  Candidate for p3.6 or a follow-up slice. — noted by worker: phase3 during p3.5 (deferred
  at p3.4 review).
- **p3.5 follow-ups:** (a) the accuracy screen shows only the **production** predictor's
  number — a v1-vs-v2 comparison on the user's own history was cut from the slice; add once
  it is useful (i.e. around / after p3.6, when both engines are worth contrasting). (b) The
  backtest replays raw period starts and is **not pregnancy-gap-aware** — a recorded loss /
  birth shows as a transient error spike rather than a modelled reset; a gap-aware
  `runBacktest` variant (slice a `List<Cycle>` history, or pass pregnancy events) would fix
  it. (c) The whole-history replay runs on the **main isolate** on screen open — fine for
  realistic histories (tens of cycles) but a candidate for a background isolate if a very
  long history janks the spinner. — noted by worker: phase3 during p3.5.
- **p3.6 follow-up — v2 migration notice (a one-time "your ranges are calibrated now"
  note):** p3.6 makes `AdaptivePredictor` the production engine. On unchanged history a
  PCOS / perimenopause user sees the predicted range widen and confidence drop the first
  time they open the app after the update; without framing that reads as a regression, not
  the honesty improvement it is. Deferred from p3.6 because a notice worth showing must fire
  **only** for users whose forecast materially moved (wider range and/or lower confidence) —
  a blanket "the engine changed" banner is changelog noise for the majority with steady
  cycles. The materiality check = run v1 and v2 on the user's live history and diff them,
  which is the **p3.5 follow-up (a)** v1-vs-v2-on-own-data comparison above; this notice is
  a thin UI slice on top of it. Build order: that comparison first, then this. Mechanism
  when built: gate on a new `app_settings` key (e.g. `prediction_engine_v2_seen`, no schema
  change — reuse `SettingsRepository`), reuse the p3.3 `_CorrectionNotice` dismissible-card
  pattern on the calendar/home prediction area, set the flag on first view (shown or not) so
  it never reappears. — noted by worker: phase3 during p3.6.
- **p4.1 follow-ups:** (a) **No `AppLifecycleState.resumed` re-plan hook.** The
  forecast-anchored reminders (`upcomingPeriod` / `fertileWindow` / `latePeriodCheckIn`) are
  re-armed on the start-up pass (`reminderSyncProvider` with `fireImmediately`) and on every
  forecast change (`ref.listen(predictionProvider)`), both via the `HomePage`-watched
  provider. A resume with **no** data change (app backgrounded for days, then reopened
  straight past `HomePage` because it was already mounted) relies on the next `HomePage`
  rebuild to re-plan — a fired one-shot that has not been re-armed yet is the acceptable
  degradation called out in the p4.1 dispatch. Fix is a small `WidgetsBindingObserver` in
  `AppGate` that calls `reminderSyncProvider`'s `replan()` on `resumed`. (b) **p1.7's
  `olf_daily_reminder` channel** — p4.1 deletes it on `ensureInitialized()` for upgraded
  installs; if that cleanup is ever removed, it must be replaced with an equivalent so the
  orphaned system-Settings entry does not return. — noted by worker: phase4 during p4.1.
- **p4.4 follow-ups:** (a) **No per-category quiet-hours exemption.** The quiet-hours
  window is app-wide, so a fixed `medication` time that falls inside it is shifted to
  the window end like every other kind — a user who deliberately set a 06:30 med
  reminder inside a 22:00–07:00 quiet window gets it at 07:00. A per-category "ignore
  quiet hours" opt-out (or exempting fixed-time kinds by default) is unbuilt; acceptable
  for now because the window defaults off and the shift is forward, never a drop.
  (b) **Daily-kind shift recomputes only at re-arm.** `applyQuietHours` for a daily kind
  is applied when the reminder is (re)armed — on enable, time change, or a sync pass —
  not continuously; if the quiet window is edited while a daily reminder is already
  scheduled, the new window only takes effect the next time that reminder is armed.
  Event-relative kinds are unaffected (the sync layer re-arms them on every forecast
  move). — noted by worker: phase4 during the Phase 4 close.
- **p5.1c follow-ups (WCAG 2.2 AA "Partially" rows, see `docs/accessibility-conformance.md`):**
  (a) **SC 2.5.7 Dragging Movements** — reordering the symptom list in
  `app/lib/src/symptom/manage_symptoms_page.dart` is drag-only
  (`ReorderableDragStartListener`); there is no single-tap "move up / move down"
  alternative for a pointer user who cannot drag. Screen-reader users already get
  `ReorderableListView`'s built-in move actions. Fix: add explicit move controls (an
  overflow menu or up/down icon buttons on each row) and a widget test that reorders
  without a drag gesture. (b) **SC 4.1.3 Status Messages** — **narrowed in p5.3.** The shared
  `announce()` helper now exists (`app/lib/src/a11y/announce.dart`) and the auto-lock
  warning + the prediction-correction notice route through it (with tests). The
  calendar month-change announcement already used `SemanticsService.announce` +
  `liveRegion: true`. **Remaining:** the plain `ScaffoldMessenger` confirmation
  SnackBars ("App lock is on.", "… removed.") are still not announced — route them
  through `announce()` too, with a test asserting the announcement fires. Working AT
  path today, no health data, does not block the Phase 5 exit gate. — noted by
  worker: phase5 during p5.1c, narrowed during p5.3.
- **p6.1 (2026-09-05): `migration_matrix_test` single-step coverage no longer validates
  v2→v3 and v4→v5 in isolation.** drift's `onUpgrade` isn't version-frozen — `m.createTable`
  always builds a table in its *current* shape — so a single step that (re)creates
  `daily_flows` (introduced v3) or `bbt_entries` (introduced v5) hands them the current (v7)
  provenance columns before the intermediate snapshot "should" carry them. Zero production
  risk: production only ever migrates to the latest `schemaVersion`, and the full v2→v7 /
  v4→v7 paths are still checked strictly by the first matrix loop. Proper fix: adopt drift's
  `stepByStep` / a generated frozen-per-version schema migrator (`drift_dev schema steps`) so
  each migration step uses that version's table definitions — its own slice, not a p6.x
  blocker. — noted by worker: phase1 during p6.1.
- (add more here)
