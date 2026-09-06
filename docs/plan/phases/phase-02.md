### Phase 2 — Privacy & security hardening

**Requirement refs:** §3, §6, §7, §8.

The Phase 1 slice-list has been expanded into task rows below (p2.1–p2.9). Rows
p2.2–p2.9 carry the intended scope; the agent starting each one fills in the
detail (files, libs, schema, edge cases) in its row as work proceeds, per §1.

**Exit gate:** lock + decoy + auto-delete + masking shipped and tested; standalone policy live;
threat model committed.

#### p2.1 — Biometric unlock on top of the PIN
- **PR:** [#25](https://github.com/Abbo0dio/olf/pull/25) — merged (squash → `0afdd48`)
- **Branch / worktree:** `feat/p2.1-biometric-unlock` / `../olf-wt/p2.1`
- **Owner:** worker: phase2
- **Depends on:** p1.8
- **Requirement refs:** §3, §7
- **Goal:** Once a PIN is set, the user can opt in to unlocking with Face ID / Touch ID /
  Android biometrics instead of typing it. The PIN always stays available as the fallback;
  biometric unlock is never a lock on its own.
- **Acceptance criteria:**
  - A "Unlock with biometrics" switch appears in Settings → Privacy only when a PIN is set;
    it is disabled with an explanatory subtitle on a device with no enrolled biometric.
  - With it on, the lock screen prompts for biometrics automatically on open and offers a
    "Use biometrics" retry button; a pass unlocks exactly like a correct PIN.
  - A failed / cancelled / unavailable biometric result silently falls back to PIN entry —
    no error nag, no lock-out.
  - No biometric data is read by the app or leaves the device; nothing new is stored
    unencrypted; the OS returns only pass/fail.
- **Tests required:** widget tests for the lock-screen auto-prompt, retry button, and PIN
  fallback; widget tests for the Settings toggle (persists; disabled when incapable); the
  seam is faked so CI never loads the platform channel.
- **Notes / detail:**
  - **No schema change.** One new `app_settings` key — `SettingKeys.biometricUnlock`
    (`'true'` / absent) — reusing the p1.6 key/value store. The PIN credential is untouched.
  - **`core`:** only the `SettingKeys.biometricUnlock` constant (biometric APIs are
    Flutter-only, so nothing else moves into `core`).
  - **`app/lib/src/security/`:** `biometric_gateway.dart` — `BiometricGateway`
    (`canAuthenticate()`, `authenticate({reason})` → `BiometricAuthResult
    { success, failed, unavailable }`); `local_auth_biometric_gateway.dart` — the production
    wrapper over the `local_auth` plugin (added to `app`; Flutter-team package, biometric
    auth only, not on the denylist); `biometric_providers.dart` —
    `biometricGatewayProvider`, `biometricCapableProvider` (`FutureProvider<bool>`),
    `biometricUnlockEnabledProvider` (`StreamProvider<bool>` off `app_settings`),
    `setBiometricUnlockEnabled`. Same seam pattern as `ReminderScheduler` (p1.7) and
    `BackupFileGateway` (p1.10): the app talks to the interface, tests inject
    `FakeBiometricGateway`.
  - `local_auth` is configured `biometricOnly: true` — the *device* passcode is **not**
    accepted for the app PIN. Biometric answers "is it me?"; the app PIN stays the only
    knowledge factor (keeps the model clean for the p2.2 decoy PIN).
  - **`PinUnlockScreen`** grows an auto-prompt (once, on open, guarded on
    enabled && capable) and a "Use biometrics" `TextButton.icon`; a success sets
    `sessionUnlockedProvider` like a correct PIN. **`settings_page.dart`** gains the switch
    under Privacy.
  - **Native config:** Android `MainActivity` now extends `FlutterFragmentActivity` (a
    `local_auth` requirement); `USE_BIOMETRIC` added to the manifest with an `audited:`
    comment (dependency-audit still PASS, 38 rules); iOS `Info.plist` gains
    `NSFaceIDUsageDescription`.
  - **Test harness:** `pumpOlf` gains a `biometricGateway` knob (defaults to an incapable
    `FakeBiometricGateway`, so every pre-p2.1 widget test is unaffected).
  - **Still a UI-level gate** — biometric unlock does not wrap the DB key either; that stays a
    §9 follow-up.
  - **Docs:** `docs/privacy-and-lock.md` (new "Biometric unlock (p2.1)" section),
    `docs/local-database.md` `app_settings` key row.

#### p2.2 — Decoy / duress PIN
- **PR:** [#26](https://github.com/Abbo0dio/olf/pull/26) — merged (squash `ee69420`)
- **Branch / worktree:** `feat/p2.2-decoy-pin` / `../olf-wt/p2.2`
- **Owner:** worker: phase2
- **Depends on:** p1.8, p2.1
- **Requirement refs:** §3, §7
- **Goal:** A second, user-set PIN that opens a plausible, empty-looking instance of the app
  instead of the real data — for a coerced-unlock situation. Entering it never reveals that a
  decoy exists.
- **Acceptance criteria:**
  - Decoy PIN opens a clean app with its own (throwaway) store; the real data is not reachable
    or detectable from the decoy session.
  - Switching back to the real data requires the real PIN; backgrounding the app ends the
    decoy session.
  - No UI anywhere hints that a decoy is configured while a decoy session is active.
- **Tests required:** unit (PIN routing: real vs decoy vs wrong, precedence, nulls);
  widget (decoy session shows no real data + no "decoy" text; real PIN still works;
  background → real PIN required; decoy PIN can't equal the real PIN).
- **Notes / detail:**
  - **No schema change.** No new dependencies — decoy reuses the existing SQLCipher +
    secure-storage infrastructure.
  - **Two vaults, two keys.** `AppVault { real, decoy }` in
    `app/lib/src/data/vault_database_opener.dart`. Real = `olf.db` under secure-storage key
    `olf.db.key.v1`; decoy = a physically separate `olf-decoy.db` under a **separate** key
    `olf.db.key.decoy.v1`, created lazily on first decoy unlock (same schema + migrations,
    starts empty). `EncryptedDatabase.open` gained an optional `fileName`;
    `SecureStorageKeyStore` / `SecureStoragePinStore` gained a `keyName` param.
  - **`appVaultProvider`** (`StateProvider<AppVault>`, default `real`) drives
    `appDatabaseProvider` through the new `vaultDatabaseOpenerProvider` seam (fake in tests).
    Switching vault closes the previous database and opens the other — only one is ever open.
  - **Routing (`core`):** `routePin(pin, {real, decoy}) → PinRoute { real, decoy, none }` in
    `pin.dart` — real checked first, both `verifyPin` runs, `null` credential never matches.
    `PinController` gained a decoy `PinStore` + `route` / `setDecoyPin` / `clearDecoyPin` /
    `matchesRealPin`. `PinUnlockScreen._submit` flips `appVaultProvider` to `decoy` and
    **awaits the decoy database** before dropping the lock, so the real vault never flashes.
  - **No hint in a decoy session.** `AppGate` skips the first-run explainer when
    `vault == decoy`; Settings hides the "Decoy PIN" setup rows unless `vault == real`, and
    inside a decoy session the ordinary "App lock (PIN)" / "Change PIN" rows operate on the
    *decoy* credential. Preferences (theme, pronouns, biometric flag) naturally come from the
    decoy database.
  - **Setup:** Settings → Privacy → "Decoy PIN" switch (only when a real PIN is set) +
    "Change decoy PIN". A candidate equal to the real PIN is rejected. Turning the real lock
    off also clears the decoy PIN.
  - **Reset on background.** `AppGate`'s `AppLifecycleListener` sets `appVaultProvider` back to
    `real` (and locks) on `paused` / `hidden`. A biometric unlock is always → real.
  - **Test harness:** `pumpOlf` gains `decoyPinStore` (default empty). `FakeVaultOpener` maps
    each vault to a database factory and records what it opened; `driftRuntimeOptions
    .dontWarnAboutMultipleDatabases` is set in the decoy test (the real+decoy pair around a
    switch is intended).
  - **Docs:** `docs/privacy-and-lock.md` ("Decoy / duress PIN (p2.2)" section),
    `docs/local-database.md` (decoy vault note).

#### p2.3 — Scheduled auto-deletion (retention window)
- **PR:** [#27](https://github.com/Abbo0dio/olf/pull/27) — merged (squash `c55bac8`)
- **Branch / worktree:** `feat/p2.3-auto-deletion` / `../olf-wt/p2.3`
- **Owner:** worker: phase2
- **Depends on:** p1.1–p1.11 (whatever data exists), p1.10
- **Requirement refs:** §3, §7, §9(11)
- **Goal:** The user picks a retention window (e.g. "keep 12 months"); anything older is purged
  automatically, and the purge also applies to backups/exports the app produces afterwards.
- **Acceptance criteria:** setting a window purges existing older rows and keeps purging on a
  schedule; "off" is the default and is honoured; a purge is logged (count only, no PHI);
  exports created after a window is set exclude purged data.
- **Tests required:** unit (cutoff maths across all tables, DST-safe); integration (set window
  → old rows gone, recent rows intact, survives restart).
- **Notes / detail:**
  - **No schema change. No new dependencies** — the purge is raw `DELETE`s over the existing
    drift schema.
  - **`RetentionWindow` enum (`core`)** — `off` (default) · `months6` · `year1` · `years2` ·
    `years3`. `cutoff(now)` is built from a fresh **local midnight** via calendar arithmetic
    (`DateTime(now.year, now.month - 6, now.day)` etc.), not a fixed `Duration`, so it is
    DST- and leap-safe and an impossible day (e.g. "31 Feb") normalises forward.
    `storageToken` / `fromStorage` persist the enum name in `app_settings`
    (`SettingKeys.retentionWindow = 'retention_window'`); any unrecognised value → `off`.
  - **`RetentionService` (`core`)** — one `sweep({now, window})` runs a `DELETE` per dated
    table **in a single transaction** and returns a `RetentionSweepResult` (per-table counts
    + cutoff date, **no row content** — safe to log per §3). `deleteWhere` maps each dated
    table to its predicate: plain `date < ?` for `daily_symptom_entries`, `daily_flows`,
    `bbt_entries`, `cervical_mucus_entries`, `cycle_events`; `COALESCE(end_date, start_date)
    < ?` for `periods` (a period straddling the cutoff is **kept**); `ended_on IS NOT NULL
    AND ended_on < ?` for `birth_control_entries` (a still-current method is **always kept**,
    however old). Config tables (`medications`, `symptom_types`, `reminders`, `app_settings`)
    are never touched — a `deleteWhere`-vs-schema partition test fails loudly if a new table
    is added without being classified.
  - **When it runs (`app`):** (1) **on launch** — `retentionStartupSweepProvider`
    (`FutureProvider`) is `ref.watch`ed by `HomePage`, so it fires once the app is past the
    lock / first-run screens; it **guards on `appVaultProvider == AppVault.real`** so a decoy
    session never purges, and no-ops when the window is `off`. (2) **on change** —
    `RetentionController.setWindow` persists the setting then sweeps immediately. (3)
    **before every backup** — `BackupController.export` calls an injected
    `sweepRetention` callback (wired to `RetentionController.sweepNow`) before it snapshots,
    so purged data never lands in a fresh `.olfbackup`.
  - **Logging:** on a non-empty sweep the app `debugPrint`s `retention: purged N entr(y|ies)
    older than YYYY-MM-DD` — a count and a date threshold only, never entry content (§3).
  - **Settings UI:** Privacy → "Auto-delete old entries" `ListTile` showing the current
    window's label; tapping opens a `RadioGroup`/`RadioListTile` picker. Choosing a
    non-`off` window shows a confirmation `AlertDialog` ("permanently deleted now and kept
    out of future backups. This can't be undone.") before it applies; switching to `off`
    applies with no prompt. A `SnackBar` confirms either way. Plain, non-alarming copy;
    gender-neutral; renders in both themes (reuses existing dialog/list components).
  - **§9(11) — reaching already-saved backup files:** **out of scope for this slice, logged
    as a follow-up** (see §9). The app does not track where the user saved past `.olfbackup`
    files (the `BackupFileGateway` hands bytes to an OS save dialog and keeps no path
    registry), so it cannot retroactively open and scrub them. What this slice *does*
    guarantee is that **every backup written from now on** already has the purge applied
    (purge-before-export, above).
- **Decisions (§7):**
  - Calendar-month/-year arithmetic from a fresh local midnight for the cutoff, matching the
    existing `date_math.dart` convention (DST-safe); no fixed `Duration`.
  - Purge = hard `DELETE` (not a soft-delete/tombstone). "Delete means delete" (§9(11)); a
    tombstone would keep the data on disk and complicate backups.
  - Startup sweep lives on `HomePage`, not `AppGate` — it must never run behind the lock or
    in a decoy session, and `HomePage` is the first widget that only mounts on the real,
    unlocked vault.
  - `RetentionService` stays in `core` (operates on the drift schema); the *scheduling* (when
    to sweep) stays in `app` providers.

#### p2.4 — Background privacy (app-switcher mask, screenshot block, lock-screen hygiene)
- **PR:** [#28](https://github.com/Abbo0dio/olf/pull/28) — merged (squash `5198074`)
- **Branch / worktree:** `feat/p2.4-background-privacy` / `../olf-wt/p2.4`
- **Owner:** worker: phase2
- **Depends on:** p1.8
- **Requirement refs:** §3, §7
- **Goal:** When the app is backgrounded, the OS app-switcher shows a neutral mask, not the
  last screen; sensitive screens cannot be screenshotted/recorded on Android; no PHI ever
  appears in a notification on the lock screen (already true for p1.7 — lock it in with a
  test).
- **Acceptance criteria:** app-switcher preview is masked on both platforms; `FLAG_SECURE`
  (or equivalent) set on sensitive routes on Android; a test asserts reminder/notification
  text carries no health detail.
- **Tests required:** widget/integration for the mask on lifecycle change; a content test for
  notification text (extends the p1.7 one).
- **Notes / detail:**
  - **No schema change. No new dependencies. No new `<uses-permission>`** — `FLAG_SECURE`
    needs none.
  - **App-switcher mask — `PrivacyShield`** (`app/lib/src/security/privacy_shield.dart`),
    mounted from `MaterialApp.builder` so it sits above every route and dialog. An
    `AppLifecycleListener` flips an opaque, content-free cover (keyed
    `privacyShieldCoverKey`; lock icon + "olf" on `colorScheme.surface`) over the whole app
    **whenever the state is not `resumed`** (`inactive` / `hidden` / `paused`). That covers
    both the task-switcher snapshot and transient interruptions (Control Centre, the
    notification shade). The masked subtree stays mounted, so nav stack / scroll / form
    state survive backgrounding. `Stack(fit: StackFit.expand)` keeps the app's full-screen
    constraints intact.
  - **Screen-capture block — `ScreenSecurity` seam** (`app/lib/src/security/screen_security
    .dart`): `abstract interface ScreenSecurity { Future<void> setSecure(bool); }`. Prod
    impl `MethodChannelScreenSecurity` talks to the `olf/screen_security` `MethodChannel`,
    handled in `MainActivity.kt` (`window.addFlags/clearFlags(FLAG_SECURE)`) —
    keeps the window out of screenshots, screen recordings **and** the Recents thumbnail on
    Android. `PrivacyShield` holds `setSecure(true)` for its whole lifetime (grabbed in
    `initState`, released in `dispose` without touching `ref`). Same fake-in-tests pattern
    as `ReminderScheduler` / `BiometricGateway`; `MissingPluginException` (iOS, desktop,
    tests) is swallowed. `screenSecurityProvider` is overridden in `pumpOlf` so no test
    ever hits the channel.
  - **iOS.** No `FLAG_SECURE` equivalent exists. `AppDelegate.swift` adds a native
    `privacyCover` `UIView` (system-background + SF `lock.fill`) on
    `applicationWillResignActive`, removed on `applicationDidBecomeActive` — the reliable
    app-switcher mask on iOS (the Flutter `PrivacyShield` is the cross-platform secondary).
    No scene manifest in `Info.plist`, so the app-delegate lifecycle hooks fire.
  - **Lock-screen hygiene.** The reminder wording is already fixed generic copy
    (p1.7; strings consolidated into `notification_copy.dart` in p4.3). p2.4 adds
    `visibility: NotificationVisibility.private` to the Android notification (redacts on a
    secure lock screen) and **broadens** the "no health details" content test to ~25 banned
    terms (period, cycle, ovulation, fertility, flow, BBT, mucus, pregnancy, mood, every
    birth-control method, …).
  - **Not gated on a setting.** The whole app is health data, so the mask and the capture
    block are always on. A per-screen `FLAG_SECURE` scope or a user opt-out is a follow-up
    (see §9).

#### p2.5 — Standalone consumer-health privacy policy screen
- **PR:** [#29](https://github.com/Abbo0dio/olf/pull/29) — merged (squash `b24ca49`)
- **Branch / worktree:** `feat/p2.5-privacy-policy` / `../olf-wt/p2.5`
- **Owner:** worker: phase2
- **Depends on:** p1.8
- **Requirement refs:** §3, §6
- **Goal:** A dedicated, plain-language privacy policy screen (not a web link), reachable from
  first run and Settings, with separate opt-ins for any collection and (future) sharing, and
  explicit "we never sell your data / we require valid legal process" commitments aligned to
  MHMDA / Nevada SB370.
- **Acceptance criteria:** screen reachable from both entry points; opt-ins are independent
  and default to off; commitments text reviewed against §3/§6; content is testable strings.
- **Tests required:** content test (each commitment/opt-in present); widget test (navigation
  from first run and Settings; opt-in state persists).
- **Notes / detail:**
  - **No schema change. No new dependencies.** Two new `SettingKeys`
    (`analytics_opt_in`, `data_sharing_opt_in`) in the existing `app_settings` store.
  - **Content — `app/lib/src/privacy/privacy_policy_content.dart`**, named constants like
    `onboarding/disclaimers.dart` so a content test asserts every commitment is on screen and
    the p1.9 copy-lint has one place to look. Eight commitment sections (heading + body):
    *stays on your device* · *we never sell your data* (no "anonymous data set" / "change of
    ownership" exception) · *we do not share it either* (no ad networks / analytics / brokers;
    the dependency-audit gate enforces it) · *if someone asks us for your data* ("we require
    valid legal process", and "nothing for us to hand over" since data never leaves the
    device) · *your consumer-health-data rights* (Washington My Health My Data Act + Nevada
    SB370: no collection/sharing without specific opt-in consent, off by default; access =
    all data is in the app + encrypted export; delete = auto-delete window or uninstall) ·
    *what we would ever collect* (nothing now; any future practice listed here, opt-in) ·
    *children* · *changes to this policy*.
  - **Screen — `PrivacyPolicyScreen`** (`app/lib/src/privacy/privacy_policy_screen.dart`), a
    plain `ConsumerWidget` + `ListView`. Renders the commitments, then a **"Your choices"**
    block with two independent `SwitchListTile`s bound to
    `analyticsOptInProvider` / `dataSharingOptInProvider` (both `StreamProvider<bool>`,
    `false` until the DB is open or the user opts in). `setAnalyticsOptIn` /
    `setDataSharingOptIn` write `'true'` / `'false'`; toggling one never touches the other.
  - **Reachable from both entry points:** a `TextButton` ("Read the full privacy policy")
    under the disclaimer points on `FirstRunScreen`, and a `ListTile` in Settings → Privacy
    (after "Auto-delete old entries"). Both `Navigator.push` the same screen.
  - **Copy** is plain, honest, second person, non-alarming; gender-neutral (the p1.9
    `inclusive_language_test` scans it automatically). Reviewed against §3 (no selling /
    legal-process posture) and §6.
- **Scope boundary with p2.7.** p2.5 is the **policy itself + the two consent switches**.
  The educational explainers — the HIPAA-gap deep-dive, the law-enforcement-access reality,
  and a step-by-step "how to delete everything" walkthrough — are **p2.7** (in-app privacy
  education). p2.5's policy states the rights and where the controls are; p2.7 will add the
  teaching pages that link to them.

#### p2.6 — Transport security baseline (for any future network use)
- **PR:** [#30](https://github.com/Abbo0dio/olf/pull/30) — merged (squash `9370943`)
- **Branch / worktree:** `feat/p2.6-transport-security` / `../olf-wt/p2.6`
- **Owner:** worker: phase2
- **Depends on:** none
- **Requirement refs:** §3, §8
- **Goal:** Establish a TLS-only + certificate-pinning HTTP client wrapper and platform ATS /
  network-security-config so that when Phase 6/9/10 first make a network call, they inherit a
  hardened default. Nothing calls out yet.
- **Acceptance criteria:** a shared client refuses cleartext and unpinned TLS; Android
  `network_security_config` and iOS ATS reviewed and documented; a test proves cleartext /
  bad-cert requests fail closed.
- **Tests required:** unit (client rejects http:// and a mismatched pin); doc of the config.
- **Notes / detail:**
  - **No new runtime dependency** (ponytail preference kept — see §9 for the cert-pinning
    package note). **No schema change.** The Dart seam uses `dart:io`'s `HttpClient`.
  - **Android — `app/android/app/src/main/res/xml/network_security_config.xml`**, wired from
    `<application>` with `android:networkSecurityConfig="@xml/network_security_config"` +
    `android:usesCleartextTraffic="false"`. `<base-config cleartextTrafficPermitted="false">`
    with **system trust anchors only** (no `<certificates src="user">`), no
    `<debug-overrides>`. Refuses plain `http://` on every API level. Debug/profile manifests
    are unchanged (they only add `INTERNET` for Flutter tooling; they do not re-enable
    cleartext).
  - **iOS — `app/ios/Runner/Info.plist`**: an explicit strict `NSAppTransportSecurity` dict —
    `NSAllowsArbitraryLoads` / `…InWebContent` / `…ForMedia` / `NSAllowsLocalNetworking` all
    `<false/>`, **no `NSExceptionDomains`**. Makes the OS default explicit and gate-able.
  - **Dart chokepoint — `app/lib/src/net/olf_http_client.dart`**: `OlfHttpClient` is the only
    sanctioned network path. `requireHttpsUrl(url)` throws `ArgumentError` on any non-`https`
    scheme *before a socket opens*; `rejectBadCertificate` is wired to
    `HttpClient.badCertificateCallback` and always returns `false` (fail closed, no feature
    handle to flip it); `certificatePins` (`Map<String, List<String>>`, SPKI-SHA256) is
    **empty today** and `_checkPins` throws for any listed-but-unenforced host so a
    "pinned but unverified" connection can never happen.
  - **Cert-pinning approach (designed, not wired).** When a backend host first exists: add its
    SPKI-SHA256 pins to `certificatePins` **and** a `<domain-config><pin-set>` in the Android
    config (keep them in step), then implement enforcement in `OlfHttpClient` (a
    `SecurityContext` trusting only the pinned chain, or a leaf-SPKI check in a
    `connectionFactory` / post-connect) replacing the `throw` in `_checkPins`. Full write-up
    in `docs/transport-security.md`.
  - **The gate.** `.github/scripts/dependency_audit.dart` gained `--net-config` and `--plist`
    (CI `dependency-audit` job updated). It **fails the build** on
    `usesCleartextTraffic="true"`, `cleartextTrafficPermitted="true"` / missing explicit
    `"false"` / `<debug-overrides>`, and any `NSAllowsArbitraryLoads*` / `NSExceptionDomains`
    in the plist. XML/plist comments are stripped before scanning so a warning comment
    naming a token does not self-trip.

#### p2.7 — In-app privacy education explainers
- **PR:** [#31](https://github.com/Abbo0dio/olf/pull/31) — merged (squash `a7585fe`)
- **Branch / worktree:** `feat/p2.7-privacy-education` / `../olf-wt/p2.7`
- **Owner:** worker: phase2
- **Depends on:** p2.5
- **Requirement refs:** §3, §9(8)
- **Goal:** Short, honest, non-alarming explainers accessible from Settings: the HIPAA gap,
  law-enforcement access reality, and exactly how to delete everything — aimed at the finding
  that only ~9% of users take any protective action.
- **Acceptance criteria:** explainers reachable from Settings; each is a testable string set;
  tone reviewed (no fear-mongering, §4/§9(12)); "delete everything" links to the real action.
- **Tests required:** content test; widget test for navigation + the delete-everything hand-off.
- **Notes / detail:**
  - **No schema change. No new runtime dependency** (ponytail preference kept) — pure Flutter
    widgets + named-constant copy.
  - **Scope boundary with p2.5.** p2.5's `PrivacyPolicyScreen` is the **policy** — the
    plain-language commitments plus the two consent switches. p2.7 is **education**: it
    explains the consumer-health-privacy landscape and gives the concrete delete steps. The
    two are separate screens; p2.7 is linked *from* the policy (and from Settings) but never
    restates it.
  - **Copy — `app/lib/src/privacy/privacy_education_content.dart`** (same named-constant +
    content-test pattern as `privacy_policy_content.dart` / `onboarding/disclaimers.dart`).
    A `PrivacyExplainer` record (`id`, `title`, `summary`, `body` paragraphs) × 3:
    - **`hipaa-gap` — "Why HIPAA doesn't cover olf":** HIPAA binds "covered entities"
      (providers, plans, their contractors), which a self-installed app is not; no federal
      health-privacy law forces a period app to protect entries and some have exploited that;
      olf's privacy does not depend on HIPAA because there is no account and nothing on a
      server; Washington's My Health My Data Act and Nevada SB370 *do* reach apps like this
      and olf is built to meet them (→ policy for specifics).
    - **`law-enforcement` — "If your data were ever requested":** cycle data has been sought,
      including after abortion bans — worth thinking about calmly; from the maker of olf
      essentially nothing could be compelled (no account, no server-side log, no cloud copy —
      a request is answered that valid legal process is required and that no such data is
      held); the real exposure is a seized/borrowed **device**, not a subpoena to a server;
      user-controlled mitigations — PIN + biometric lock, the decoy PIN, the auto-delete
      window. Ends "This is context, not legal advice."
    - **`delete-everything` — "How to delete everything":** everything is one encrypted DB on
      the device, no cloud copy / account. Renders `deleteEverythingSteps` as a **numbered
      list** — (1) optional encrypted export via Backup & restore, (2) set an auto-delete
      window, (3) uninstall removes the encrypted DB + its key, nothing recoverable, decoy
      space goes too. A `FilledButton.tonalIcon` **"Open Backup & restore"** pushes the real
      `BackupPage` — the actionable hand-off that answers the "~9% take a protective action"
      finding.
  - **Screens — `app/lib/src/privacy/privacy_education_screen.dart`:** `PrivacyEducationScreen`
    (index: intro + one `ListTile` per explainer) → `PrivacyExplainerScreen` (body paragraphs;
    for the delete one, the numbered steps + the Backup & restore button). Plain
    `Navigator.push`, `MaterialPageRoute` — no router change, no new provider.
  - **Entry points:** a "Privacy basics" `ListTile` (`Icons.school_outlined`) in
    `settings_page.dart` right under "Privacy policy", and a divider + the same link at the
    bottom of `PrivacyPolicyScreen`.
  - **Tone (§4 / §9(12)):** second person, calm, no fear vocabulary — a content test asserts
    the copy contains none of panic / terrifying / nightmare / disaster / catastroph / doom /
    scary. Gender-neutral — the p1.9 inclusive-language lint scans the new constants
    automatically (the abortion-ban paragraph avoids "women" etc.).
  - **Tests — `app/test/privacy/privacy_education_test.dart`:** content group (exactly three
    explainers, distinct non-empty title/summary/body; per-explainer key-phrase assertions;
    the numbered delete steps end in "uninstall" / "nothing recoverable"; the tone check) +
    widget tests (Settings → "Privacy basics" lists all three; reachable from the policy
    screen; the delete explainer's button lands on the real `BackupPage`; each explainer
    opens with its title + first paragraph). 10 new tests; app suite 116 green.

#### p2.8 — Threat model + data-flow diagram committed to the repo
- **PR:** [#32](https://github.com/Abbo0dio/olf/pull/32) — merged (squash `834a4d4`)
- **Branch / worktree:** `feat/p2.8-threat-model` / `../olf-wt/p2.8`
- **Owner:** worker: phase2
- **Depends on:** none
- **Requirement refs:** §3, §7, §8
- **Goal:** A `docs/threat-model.md` (assets, adversaries, trust boundaries, mitigations,
  residual risks) plus a data-flow diagram, established as a living document reviewed at each
  phase gate.
- **Acceptance criteria:** doc covers the current architecture (on-device store, key storage,
  PIN/biometric gate, backup file, no backend); each Phase 0–2 mitigation is cross-referenced;
  a "review log" section is started.
- **Tests required:** n/a (documentation) — but a CI check that the file exists and the review
  log has an entry for the current phase.
- **Notes / detail:**
  - **No schema change. No new runtime dependency. No new permission. No new workflow.**
    Documentation + one pure-Dart guard test in the existing `test` job.
  - **`docs/threat-model.md`** — the living security-design doc. Sections: purpose &
    review cadence; **assets** (cycle/health entries, the SQLCipher key, the PIN/decoy-PIN
    hashes, preferences, `.olfbackup` files, derived predictions); **adversaries** (a person
    with brief physical access to an unlocked phone; a person who can seize the device and
    compel unlock; a co-owner / abuser sharing the device; a thief; malware / another app on
    the device; a network attacker (future); a supply-chain attacker via a dependency; law
    enforcement / civil subpoena; **not** in scope: a nation-state with a device 0-day, a
    hardware forensic lab); **trust boundaries** (the OS keystore ↔ app; the app process ↔
    the encrypted DB file; the app ↔ the OS share sheet / file picker; the app ↔ the
    screen/recents buffer; the app ↔ the network (no traffic today); the repo ↔ its
    dependency graph); **data-flow** as a committed **Mermaid** diagram (renders on GitHub,
    no tooling, no binary) plus a short ASCII fallback, covering: entry → drift → SQLCipher
    file; key create/read via `flutter_secure_storage`; PIN/biometric gate before the DB
    opens; decoy PIN → separate empty vault; retention sweep deleting rows on launch/export;
    export → encrypt → OS save dialog; lifecycle → screen mask; the `OlfHttpClient` seam with
    **no** backend on the other side; **mitigations table** cross-referencing every Phase 0–2
    control to its slice (see below); **residual risks** (pulled from the §9 follow-up
    bullets — key not bound to PIN, no lockout/backoff, iOS screenshot gap, decoy DB left on
    disk when disabled, saved backups not retro-scrubbed, cert-pinning designed-not-wired,
    etc.); and a **`## Review log`** started with a **Phase 2** entry (date, reviewer =
    worker: phase2, what was checked, no changes required).
  - **Mitigation cross-reference (each Phase 0–2 control → slice):** no-account / local-only
    store + SQLCipher at rest → **p0.4**; CI dependency-audit denylist (no ad/analytics SDK)
    + branch protection → **p0.3**; PIN gate + anonymous-by-default + disclaimers + first-run
    explainer → **p1.8**; encrypted backup/restore (`.olfbackup`, AES-GCM, gzip) → **p1.10**;
    discreet dark theme → **p1.9**; biometric unlock over the PIN → **p2.1**; decoy / duress
    PIN → **p2.2**; scheduled auto-deletion (retention window + purge-before-export) →
    **p2.3**; background app-switcher mask + `FLAG_SECURE` + no-PHI recents → **p2.4**;
    standalone consumer-health privacy policy + consent switches → **p2.5**; TLS-only /
    no-cleartext platform config + `OlfHttpClient` chokepoint + transport gate → **p2.6**;
    in-app privacy education (HIPAA gap, law-enforcement reality, delete steps) → **p2.7**;
    this threat model + its guard → **p2.8**.
  - **CI guard — `core/test/threat_model_doc_test.dart`** (pure `dart:io`, picked up by the
    existing `core — unit tests` step in the `test` job — same mechanism as
    `dependency_audit_test.dart` reading real repo files; **no `ci.yml` change**). Asserts:
    (1) `../docs/threat-model.md` exists and is non-trivial; (2) it has the required section
    headings (`## Assets`, `## Adversaries`, `## Trust boundaries`, `## Data flow`,
    `## Mitigations`, `## Review log`); (3) it contains a fenced ```mermaid``` block.
    *(Originally the test also enforced (4): the `## Review log` names the current phase,
    with the current phase parsed from the old monolithic `DEVELOPMENT_PLAN.md`'s
    `**Status:**` lines. When the plan was split into `docs/plan/` (2026-09-06) and task
    status moved to `.herdsman/state.md`, that check moved to the Orchestrator's manual
    phase-close gate — herdsman `orchestrator/phase-loop.md`.)*
  - **Copy:** neutral, non-alarming, gender-neutral; the p1.9 inclusive-language lint already
    scans `app/lib` + `core/lib` string literals, not `docs/`, so the doc's tone is guarded
    by review, not lint (noted as acceptable — it is design documentation, not user copy).

#### p2.9 — Dependency-audit gate: strict + documented release blocker
- **PR:** [#33](https://github.com/Abbo0dio/olf/pull/33) — merged (squash `314bba0`)
- **Branch / worktree:** `feat/p2.9-audit-release-blocker` / `../olf-wt/p2.9`
- **Owner:** worker: phase2
- **Depends on:** p0.3
- **Requirement refs:** §3
- **Goal:** Promote the p0.3 dependency-audit from "green by convention" to an explicit,
  documented release blocker: no waivers, failure text points at the process, and the release
  checklist names it.
- **Acceptance criteria:** audit failure is unambiguous and un-waivable in CI; `docs/
  dependency-audit.md` states it is a release blocker with the escalation path; a release
  checklist doc references it.
- **Tests required:** extend `core/test/dependency_audit_test.dart` for any new rule classes;
  doc review.
- **Notes / detail:**
  - **No schema change. No new runtime dependency. No new permission. No new workflow**
    (ci.yml hardened in place). This is the **last Phase 2 build slice** — the phase-close
    doc bump comes after.
  - **Un-waivable in CI — the three soft-pass surfaces closed:**
    1. **A skipped audit now fails the board.** `ci-ok` (the required `CI OK` check) already
       failed on a job `result` of `failure` / `cancelled`; it now *also* fails unless the
       `dependency-audit` job `result` is exactly `success`. Previously, removing the Flutter
       workspace (or the job's `if:` guard) would let the audit **skip** while `CI OK` stayed
       green — that path is gone. Uses `jq '."dependency-audit".result'` on `toJSON(needs)`.
    2. **The CI arguments are locked.** A new test in `dependency_audit_test.dart` reads
       `.github/workflows/ci.yml` and asserts the audit still runs with all five inputs
       (`--denylist`, both `--lock`s, `--manifest`, `--net-config`, `--plist`), the
       stale-lock `git diff --exit-code` guard is still present, no job carries
       `continue-on-error`, and `ci-ok` still `needs:` + hard-checks `dependency-audit`.
       Quietly dropping `--lock app/pubspec.lock` (etc.) now fails the `test` job.
    3. **No script bypass.** Tests assert the script has **no** `--skip` / `--force` /
       `--allow` / `--allowlist` / `--no-fail` / `--waive` option and that **no environment
       variable** (`SKIP_DEPENDENCY_AUDIT`, `OLF_SKIP_AUDIT`, `NO_AUDIT`, …) suppresses a
       violation — it still exits 1.
  - **Failure output points at the process** (`.github/scripts/dependency_audit.dart`). After
    the violation list the script now prints: this is a RELEASE BLOCKER (p2.9), it cannot be
    waived / skipped / overridden, there is no flag / env var / allowlist, then the concrete
    steps — find who pulls the package in (`dart pub deps -s list` / `flutter pub deps -s
    list`), **remove/replace it** as the default fix; a genuine false positive from an
    over-broad `~`/`re:` rule is handled by the **security reviewer narrowing that rule** in
    the same PR with recorded sign-off (never a carve-out, never removing a rule to go
    green); removing an entry needs sign-off. Links `docs/dependency-audit.md` +
    `docs/release-checklist.md`. The exit-2 "bad invocation" path also now states plainly
    that the gate did not run and that this is still a failure.
  - **`docs/dependency-audit.md`** gains a **"Release blocker (p2.9)"** section: the
    un-waivable properties spelled out (no flag, no env var, no `continue-on-error`, a skip
    counts as a failure, the CI args are test-locked) and the **escalation path** — who
    decides (the security-reviewer role; for a solo maintainer, an explicit written
    self-review in the PR), and the two legitimate outcomes (remove the dependency; or
    narrow a false-positive rule with sign-off). Local-run snippet updated to the full
    five-flag invocation; exit-code note says any non-zero (incl. exit 2) fails CI.
  - **`docs/release-checklist.md`** (new, deliberately short — ponytail): a pre-release
    checklist with **BLOCKER** line items — `CI OK` green, **dependency audit ran and
    passed** (linking the escalation path), no unreviewed runtime dependency, threat-model
    Review log current for the phase — plus lighter checks (version bump, changelog,
    migration test, size report) and a "who signs off" note.
  - **`core/test/dependency_audit_test.dart`** — the `run` helper gained an `environment:`
    parameter; +4 tests in a `release blocker (p2.9)` group (failure-text content, env-var
    no-op, no bypass flag in the script source, CI wiring lock), and the exit-2 test now
    also asserts the "gate did not run" message. 315 core tests pass (was 311).
**Phase 2 exit gate:** the MUST-HAVE privacy/security controls from `requirements.md` §3
(and §6/§7/§8) are shipped, tested, and enforced: PIN + biometric lock, decoy/duress PIN,
scheduled auto-deletion, background masking, a standalone consumer-health privacy policy,
a TLS-only transport baseline, in-app privacy education, a committed threat model, and an
un-waivable dependency-audit release blocker.

**Exit-gate status — MET (2026-08-31).** All nine slices p2.1–p2.9 merged to `main`
(PRs #25–#33) with CI green; each slice's acceptance criteria were verified in its PR.

- **Lock + decoy + auto-delete + masking shipped and tested:** biometric unlock over the
  PIN (**p2.1**, PR #25 `0afdd48`); decoy/duress PIN routing to a separate empty vault
  (**p2.2**, PR #26 `ee69420`); retention window with purge-before-export (**p2.3**, PR #27
  `c55bac8`); app-switcher mask + `FLAG_SECURE` + no-PHI recents (**p2.4**, PR #28
  `5198074`). Each carries unit + widget/seam tests headless in CI.
- **Standalone policy live:** in-app `PrivacyPolicyScreen` with the commitments + two
  default-off consent switches, reachable from first-run and Settings, MHMDA/SB370-aligned
  (**p2.5**, PR #29 `b24ca49`), plus the honest, non-alarming in-app explainers — HIPAA
  gap, law-enforcement reality, how to delete everything (**p2.7**, PR #31 `a7585fe`).
- **Threat model committed:** `docs/threat-model.md` (assets / adversaries / trust
  boundaries / data-flow diagram / mitigation cross-reference to every Phase 0–2 slice /
  residual risks / phase-gate Review log) with a CI guard (**p2.8**, PR #32 `834a4d4`).
- **Supporting hardening:** TLS-only Android/iOS config + `OlfHttpClient` chokepoint +
  transport gate (**p2.6**, PR #30 `9370943`); the dependency-audit promoted to an
  explicit, un-waivable release blocker with a documented escalation path and a
  `docs/release-checklist.md` (**p2.9**, PR #33 `314bba0`).

Outstanding non-blockers carried forward: the per-slice §9 follow-ups (key-to-PIN binding,
failed-attempt lockout/backoff, iOS screenshot gap, decoy-DB cleanup on disable, retro-scrub
of saved backups, cert-pinning enforcement, native-dep audit coverage), and the p0.5 manual
physical-device smoke table.

---
