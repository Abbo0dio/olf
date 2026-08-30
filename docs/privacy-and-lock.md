# Anonymous-by-default, first-run explainer, and the app lock (p1.8 · p2.1)

This documents the privacy posture the app ships with and the optional PIN lock.
Requirement refs: `requirements.md` §3 (privacy & data security), §6 (regulatory /
disclaimers), §9(8) (privacy distrust). p2.1 adds an optional biometric unlock
shortcut (below). A decoy PIN, scheduled auto-deletion, and screenshot/background
masking are still **Phase 2**.

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
screen also offers an **optional** PIN (opt-in, unchecked by default).

Covered by `app/test/onboarding/first_run_test.dart`.

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

### Not yet (Phase 2)

A decoy PIN + decoy data; failed-attempt lockout / backoff; scheduled
auto-deletion; screenshot / app-switcher masking; moving the PIN hash off the
main isolate and raising the work factor, or binding the DB key to the PIN /
biometric with a real KDF.

Covered by `app/test/security/pin_gate_test.dart`,
`app/test/security/biometric_unlock_test.dart`,
`app/test/settings/settings_page_test.dart`, and
`core/test/security/pin_test.dart`.
