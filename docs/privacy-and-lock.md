# Anonymous-by-default, first-run explainer, and the app lock (p1.8 · p2.1 · p2.2 · p2.3 · p2.4 · p2.5 · p2.7)

This documents the privacy posture the app ships with and the optional PIN lock.
Requirement refs: `requirements.md` §3 (privacy & data security), §6 (regulatory /
disclaimers), §7 (duress / coercion), §9(8) (privacy distrust), §9(11) (delete
means delete). p2.1 adds an optional biometric unlock shortcut, p2.2 adds an
optional decoy / duress PIN, p2.3 adds an optional scheduled auto-deletion
window, p2.4 adds always-on background privacy (app-switcher mask +
screen-capture block), p2.5 adds the standalone privacy-policy screen and
its two consent switches, and p2.7 adds three in-app privacy-education
explainers — all below.

## Anonymous by default

There is no account, no sign-in, and no network call anywhere in the app. A
fresh install is fully usable with zero personal data entered — you land on an
empty period calendar. Data lives only in the on-device SQLCipher database
(`docs/local-database.md`), whose key is in the platform secure enclave.

Covered by `app/test/onboarding/first_run_test.dart` ("continue with no PIN → app
is fully usable") and the pre-existing `app/test/widget_test.dart` empty-state
tests.

## First-run privacy explainer

`app/lib/src/onboarding/` — shown once, before anything else, gated on the
`onboarding_complete` key in `app_settings` (via `firstRunDoneProvider`).

The copy lives as named constants in `onboarding/disclaimers.dart` so a content
test can assert every point is actually on screen, and so p1.9's language sweep
has one place to look. Four points, reviewed against §3 / §6:

| Point | Why it's here |
|---|---|
| **Your data stays on this device** — no account, no cloud, encrypted locally, never sold/shared | §3 on-device storage + "we never sell / require legal process" |
| **HIPAA does not apply here** | §3 — cycle apps generally aren't HIPAA covered entities; say so plainly |
| **Not medical advice** | §6 — non-device apps must carry a clear disclaimer |
| **Not a contraceptive** | §6 — same |

Tone is deliberately plain and non-alarming (§4 / §9(12) — no fear-mongering).

"Got it — continue" writes `onboarding_complete = 'true'` and enters the app. The
screen also offers an **optional** PIN (opt-in, unchecked by default), and a
link to the full privacy policy (p2.5, below).

Covered by `app/test/onboarding/first_run_test.dart`.

## Standalone privacy policy (p2.5)

The whole policy lives in the app — there is no separate web version.
`PrivacyPolicyScreen` (`app/lib/src/privacy/privacy_policy_screen.dart`) is
reachable from **two** places: a "Read the full privacy policy" link on the
first-run screen, and **Settings → Privacy → Privacy policy**. Requirement refs:
§3, §6; aligned with Washington's My Health My Data Act (MHMDA) and Nevada SB370.

The copy is named constants in `privacy/privacy_policy_content.dart` (same
pattern as `disclaimers.dart` — a content test asserts every commitment is on
screen; the p1.9 copy-lint scans it). Eight commitments:

| Commitment | Substance |
|---|---|
| Everything stays on your device | no account / server; encrypted local DB only |
| We never sell your data | explicit; no "anonymous set" / "change of ownership" carve-out |
| We do not share it either | no ad networks / analytics / brokers; the dependency-audit gate enforces it |
| If someone asks us for your data | "we require valid legal process" — and nothing to hand over, since data never leaves the device |
| Your consumer-health-data rights | MHMDA / SB370: no collection or sharing without specific opt-in consent (off by default); access = data is all in the app + encrypted export; delete = auto-delete window or uninstall |
| What we would ever collect | nothing now; any future practice listed here and opt-in |
| Children | not directed at under-13s; nothing collected from anyone |
| Changes to this policy | "last reviewed" date moves with the wording; new practices are opt-in; continued use never counts as agreement |

### The two consent switches ("Your choices")

Both are **independent** and **default off**, backed by `app_settings` keys and
`privacy/privacy_providers.dart`:

| Switch | Key | Meaning |
|---|---|---|
| Allow on-device usage analytics | `analytics_opt_in` | gates a *possible future* on-device metric; nothing is collected while off, and nothing leaves the device regardless |
| Allow sharing data with third parties | `data_sharing_opt_in` | olf shares nothing today; stays off unless deliberately turned on for a named future feature |

Nothing in the app reads these yet — they exist so any future change is the
user's decision. The **educational explainers** (HIPAA gap, law-enforcement
reality, a step-by-step delete walkthrough) are **p2.7**, below.

Covered by `app/test/privacy/privacy_policy_test.dart`.

## In-app privacy education (p2.7)

Three short, plain-language explainers, kept **separate** from the policy: the
policy (p2.5) states the commitments and holds the consent switches; these
explain the landscape and — the point of the slice — how to remove your data.
`PrivacyEducationScreen` (`app/lib/src/privacy/privacy_education_screen.dart`)
is an index reachable from **Settings → Privacy basics** and from a link at the
bottom of `PrivacyPolicyScreen`. Each row opens `PrivacyExplainerScreen`.
Requirement refs: §3, §9(8); tone §4 / §9(12).

Copy is named constants in `privacy/privacy_education_content.dart` (same
pattern as `privacy_policy_content.dart` / `disclaimers.dart` — a content test
asserts every point is on screen; the p1.9 copy-lint scans it). The three:

| Explainer | Substance |
|---|---|
| Why HIPAA doesn't cover olf | HIPAA binds "covered entities" (providers, plans, their contractors); a self-installed app is none, and no federal law fills the gap. olf's privacy doesn't depend on HIPAA — no account, nothing on a server. Washington's MHMDA and Nevada SB370 *do* reach apps like this and olf is built to meet them. |
| If your data were ever requested | Cycle data has been sought, including after abortion bans. From the maker of olf, essentially nothing could be compelled — no account, no server-side log, no cloud copy; a request is answered that valid legal process is required and that no such data is held. The real exposure is a seized/borrowed **device**, not a server subpoena. User-controlled mitigations: PIN + biometric lock, decoy PIN, auto-delete window. Ends "This is context, not legal advice." |
| How to delete everything | Everything is one encrypted DB on the device. Numbered steps: (1) optional encrypted export via **Backup & restore**, (2) set an auto-delete window, (3) uninstall — removes the encrypted DB and its key, nothing recoverable, the decoy space goes too. |

The delete explainer renders its steps as a numbered list and shows an **"Open
Backup & restore"** button that pushes the real `BackupPage` — the actionable
hand-off, aimed at the finding that only a small fraction of users ever take a
protective action.

Tone is second-person and calm; a content test asserts the copy contains no
alarmist vocabulary (panic / terrifying / nightmare / disaster / catastroph /
doom / scary), and the p1.9 inclusive-language lint covers gendered phrasing.

Covered by `app/test/privacy/privacy_education_test.dart`.

## The app lock (PIN)

**Scope: a UI-level gate, not a cryptographic boundary.** The database is already
encrypted at rest; in Phase 1 the PIN does **not** derive or wrap that key. It
only decides whether `AppGate` shows the app or the lock screen. This is called
out in `core/lib/src/security/pin.dart` and is a Phase 2 follow-up.

### Storage

- `core/lib/src/security/pin.dart` — pure logic: `validatePin` (4–12 digits),
  `derivePinCredential` / `hashPin` (iterated HMAC-SHA256, work factor
  `defaultPinIterations = 30000`), `verifyPin` (constant-time compare),
  `PinCredential` (salt + iteration count + hash; JSON round-trip).
- `core/lib/src/security/pin_store.dart` — the `PinStore` interface. Presence of
  a stored `PinCredential` **is** the "lock is on" signal — there is no separate
  flag.
- `app/lib/src/security/secure_storage_pin_store.dart` — `PinStore` over
  `flutter_secure_storage` (iOS Keychain / Android Keystore), mirroring
  `SecureStorageKeyStore`. The PIN itself is never stored.

### Gate

`app/lib/src/app_gate.dart` (`AppGate`, the `MaterialApp.home`):

```
database opens ─▶ first-run explainer (until acknowledged)
              ─▶ PIN lock (if a credential exists and the session is locked)
              ─▶ HomePage
```

A database error falls through to `HomePage`, which owns the fail-safe screen.
`sessionUnlockedProvider` (a `StateProvider<bool>`) tracks the current session;
`AppGate` re-locks it via an `AppLifecycleListener` when the app is paused/hidden.

### Setup & management

- First-run screen: optional opt-in with confirm field.
- `app/lib/src/settings/settings_page.dart` (home → gear icon): an "App lock"
  switch to set / change / remove the PIN afterwards — so it's genuinely
  optional and reversible without reinstalling.

## Biometric unlock (p2.1)

An **opt-in shortcut past the PIN**, never a lock on its own. It is only offered
once a PIN is set, and PIN entry always stays on screen as the fallback.

- `app/lib/src/security/biometric_gateway.dart` — the `BiometricGateway`
  interface (`canAuthenticate()`, `authenticate({reason})` →
  `BiometricAuthResult { success, failed, unavailable }`). Same seam pattern as
  `ReminderScheduler` (p1.7) and `BackupFileGateway` (p1.10): the app talks to
  the interface, `LocalAuthBiometricGateway` wraps the `local_auth` plugin, and
  tests inject `FakeBiometricGateway`, so CI never loads the platform channel.
- `local_auth` is configured with `biometricOnly: true` — the *device* passcode
  is **not** accepted in place of the app PIN. Biometric answers "is it me?";
  the app PIN is the only knowledge factor. This keeps the model clean for the
  p2.2 decoy PIN.
- `SettingKeys.biometricUnlock` (`'true'` / absent) in `app_settings` holds the
  opt-in. `biometric_providers.dart` exposes `biometricCapableProvider`
  (hardware + enrolment check) and `biometricUnlockEnabledProvider` (the
  setting), plus `setBiometricUnlockEnabled`.
- `PinUnlockScreen`: when enabled **and** the device is capable, the biometric
  prompt fires once automatically on open, and a "Use biometrics" button retries
  it. A failed/cancelled/unavailable result just falls back to the PIN with no
  nag. Success sets `sessionUnlockedProvider`, exactly like a correct PIN.
- Settings → Privacy → "Unlock with biometrics" switch (shown only when a PIN is
  set; disabled with an explanatory subtitle when the device has no enrolled
  biometric).
- Native config: Android `MainActivity` extends `FlutterFragmentActivity` (a
  `local_auth` requirement); `USE_BIOMETRIC` is declared in the manifest with an
  `audited:` comment; iOS carries `NSFaceIDUsageDescription`. No biometric data
  is read by the app and none leaves the device — the OS returns only pass/fail.
- **Still a UI-level gate.** Biometric unlock does not wrap the database key
  either; that remains a Phase 2 follow-up (§9).

## Decoy / duress PIN (p2.2)

An **optional second PIN** that opens a *separate, empty* copy of the app. For a
coerced-unlock situation: hand over the decoy PIN and nothing of the real data is
visible or reachable, with no on-screen sign that a decoy exists.

- **Two vaults, two keys.** `AppVault { real, decoy }` (`data/vault_database_opener
  .dart`). The real vault is `olf.db` under `olf.db.key.v1`; the decoy vault is
  `olf-decoy.db` under a *separate* secure-storage key `olf.db.key.decoy.v1`,
  created lazily on first decoy unlock. `appDatabaseProvider` watches
  `appVaultProvider` and opens exactly one — switching vaults closes the other.
- **Routing.** `routePin(pin, {real, decoy})` in `core/lib/src/security/pin.dart`
  returns `PinRoute { real, decoy, none }` (real checked first; both `verifyPin`
  runs). `PinController.route` reads both credentials; `PinUnlockScreen._submit`
  flips `appVaultProvider` to `decoy` and awaits the decoy database *before*
  dropping the lock, so the real vault is never briefly shown.
- **Decoy credential** lives in secure storage under `olf.pin.decoy.credential.v1`
  (`decoyPinStoreProvider`), independent of the real credential.
- **No hint in a decoy session.** `AppGate` skips the first-run explainer when
  `vault == decoy` (a "lived-in" app), and Settings hides the "Decoy PIN" setup
  rows unless `vault == real`. Inside a decoy session the ordinary "App lock
  (PIN)" / "Change PIN" rows operate on the *decoy* credential, and preferences
  (theme, pronouns, biometric flag) come from the decoy database.
- **Setup.** Settings → Privacy → "Decoy PIN" switch (only when a real PIN is
  set). A candidate equal to the real PIN is rejected (`matchesRealPin`).
- **Reset on background.** The `AppLifecycleListener` in `AppGate` sets
  `appVaultProvider` back to `real` (and locks) on `paused` / `hidden`, so a
  decoy session never survives an app switch — the next unlock re-chooses.
- **Biometric always → real.** A biometric unlock never opens the decoy vault.
- Turning the real lock off also clears the decoy PIN. Turning the decoy PIN off
  leaves the decoy database file in place (see §9 follow-ups).

## Scheduled auto-deletion (p2.3)

An **optional retention window**: the user picks how long dated entries are kept
and anything older is deleted automatically. Off by default — nothing is ever
removed unless the user turns this on. Requirement refs: §3, §7, §9(11) ("delete
means delete").

- **`RetentionWindow`** (`core/lib/src/retention/retention_window.dart`) — `off`
  (default) · `months6` · `year1` · `years2` · `years3`. `cutoff(now)` is a fresh
  **local midnight** from calendar arithmetic (not a fixed `Duration`), so it is
  DST- and leap-safe. The choice is stored as the enum name under
  `SettingKeys.retentionWindow` (`retention_window`) in `app_settings`; any
  unrecognised value reads back as `off`.
- **`RetentionService`** (`core/lib/src/retention/retention_service.dart`) — one
  `sweep({now, window})` runs a `DELETE` per dated table **in a single
  transaction** and returns a `RetentionSweepResult` (per-table row *counts* +
  the cutoff date — **never row content**, so it is safe to log per §3). A period
  straddling the cutoff is kept (`COALESCE(end_date, start_date)`); a still-current
  birth-control method (`ended_on IS NULL`) is kept regardless of age. Config
  tables (`medications`, `symptom_types`, `reminders`, `app_settings`) are never
  touched.
- **When it runs** (`app/lib/src/retention/retention_providers.dart`): on app
  launch (`retentionStartupSweepProvider`, watched by `HomePage` so it is always
  past the lock / first-run screens, and **guarded on the real vault** so a decoy
  session never purges); immediately when the window is changed
  (`RetentionController.setWindow`); and before every backup export
  (`BackupController` calls the injected `sweepRetention` hook first, so purged
  data never lands in a fresh `.olfbackup`).
- **Logging.** A non-empty sweep `debugPrint`s `retention: purged N entr(y|ies)
  older than YYYY-MM-DD` — a count and a date only, no entry content (§3).
- **Settings.** Privacy → "Auto-delete old entries" → a radio picker. Choosing a
  window shows a plain, non-alarming confirmation ("permanently deleted now and
  kept out of future backups — this can't be undone") before applying; turning it
  back to *off* applies with no prompt.
- **Not retroactive to saved backups.** `.olfbackup` files the user already saved
  elsewhere are **not** reached — the app keeps no record of where they went. Only
  backups written *after* a window is set are pre-purged. See the p2.3 follow-up
  in `DEVELOPMENT_PLAN.md` §9.

## Background privacy (p2.4)

Always on — the whole app is health data, so there is no setting to weaken it.
Requirement refs: §3 ("blur when backgrounded"), §7.

- **App-switcher mask — `PrivacyShield`** (`app/lib/src/security/privacy_shield
  .dart`), mounted from `MaterialApp.builder` so it sits above every route and
  dialog. An `AppLifecycleListener` paints an opaque, content-free cover (a lock
  icon + "olf" on `colorScheme.surface`, keyed `privacyShieldCoverKey`) over the
  whole app **whenever the lifecycle state is not `resumed`** — so the OS
  task-switcher snapshot, and transient interruptions like Control Centre or the
  notification shade, never show real data. The masked subtree stays mounted, so
  the nav stack, scroll position and any half-filled form survive backgrounding.
- **Screen-capture block — `ScreenSecurity` seam** (`app/lib/src/security/
  screen_security.dart`): `setSecure(bool)` behind the `olf/screen_security`
  method channel, handled in `MainActivity.kt` as
  `window.addFlags/clearFlags(FLAG_SECURE)`. `FLAG_SECURE` keeps the Android
  window out of screenshots, screen recordings **and** the Recents thumbnail.
  `PrivacyShield` holds it `true` for the app's whole lifetime. Same
  fake-in-tests seam as `ReminderScheduler` (p1.7) / `BiometricGateway` (p2.1);
  `MissingPluginException` is swallowed on platforms with no handler.
- **iOS.** There is no `FLAG_SECURE` equivalent, so screenshots/recordings can't
  be blocked. `AppDelegate.swift` adds a native cover `UIView` on
  `applicationWillResignActive` (removed on `applicationDidBecomeActive`) as the
  reliable app-switcher mask; the Flutter `PrivacyShield` is the cross-platform
  secondary.
- **Lock-screen hygiene.** The one reminder notification already uses fixed
  generic copy (`reminderNotificationTitle` / `Body`, p1.7). p2.4 adds
  `visibility: NotificationVisibility.private` (redacts on a secure lock screen)
  and broadens the "no health details" content test to ~25 banned terms.

### Not yet (Phase 2)

Failed-attempt lockout / backoff; a background/periodic auto-deletion sweep (p2.3
runs on launch / change / export only) and reaching already-saved backup files;
per-screen `FLAG_SECURE` scoping or a user opt-out (p2.4 is all-or-nothing);
iOS screenshot/recording blocking (no OS API); wiping the decoy database when the
decoy PIN is removed; moving the PIN hash off the main isolate and raising the
work factor, or binding each vault's DB key to its PIN / biometric with a real
KDF.

Covered by `app/test/security/pin_gate_test.dart`,
`app/test/security/biometric_unlock_test.dart`,
`app/test/security/decoy_pin_test.dart`,
`app/test/security/privacy_shield_test.dart`,
`app/test/retention/retention_test.dart`,
`app/test/backup/backup_controller_test.dart`,
`app/test/reminders/reminder_controller_test.dart`,
`app/test/settings/settings_page_test.dart`,
`core/test/retention/`, and
`core/test/security/pin_test.dart`.
