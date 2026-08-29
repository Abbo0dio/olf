# Anonymous-by-default, first-run explainer, and the app lock (p1.8)

This documents the privacy posture the app ships with and the optional PIN lock.
Requirement refs: `requirements.md` §3 (privacy & data security), §6 (regulatory /
disclaimers), §9(8) (privacy distrust). Biometric unlock, a decoy PIN, scheduled
auto-deletion, and screenshot/background masking are **Phase 2**.

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

### Not yet (Phase 2)

Biometric unlock; a decoy PIN + decoy data; failed-attempt lockout / backoff;
scheduled auto-deletion; screenshot / app-switcher masking; moving the hash off
the main isolate and raising the work factor, or binding the DB key to the PIN
with a real KDF.

Covered by `app/test/security/pin_gate_test.dart`,
`app/test/settings/settings_page_test.dart`, and
`core/test/security/pin_test.dart`.
