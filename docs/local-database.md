# Local database

The on-device store established in **p0.4**. Everything in Phase 1 extends it.

## Shape

| Layer | Lives in | Responsibility |
|-------|----------|----------------|
| Schema, queries, migrations | `core` (`olf_core`) | `AppDatabase` (drift), tables, `MigrationStrategy`, repositories. Pure Dart — **no** Flutter, no SQLCipher, no `path_provider`. |
| Encrypted executor | `app` (`EncryptedDatabase`) | Builds the `QueryExecutor` with SQLCipher (`sqlcipher_flutter_libs`) and hands it to `AppDatabase`. |
| Key storage | `app` (`SecureStorageKeyStore`) implementing `core`'s `DatabaseKeyStore` | 256-bit key in the iOS Keychain / Android Keystore via `flutter_secure_storage`. |

`core` never learns how bytes are stored, so the future desktop shell can supply its
own executor. Tests supply `NativeDatabase.memory()` / a temp file (plain SQLite — encryption
is orthogonal to schema and query logic).

## Encryption & fail-safe

`EncryptedDatabase.open()`:

1. Read the key from secure storage.
2. **Key missing + database file exists** → throw `MissingDatabaseKeyException`. The app shows a
   dead-end "Can't unlock your data" screen and writes nothing. We never replace an existing
   encrypted file with a fresh or unkeyed one.
3. **Key missing + no file** → first run: generate 32 random bytes (`Random.secure`), base64,
   store, continue.
4. Open with `PRAGMA key`, then assert `PRAGMA cipher_version` is non-empty — a plain SQLite
   would ignore `PRAGMA key` and write plaintext, so we refuse to proceed if SQLCipher isn't
   actually loaded.

No health data is ever written outside this encrypted file. No PHI goes to logs or (later)
notification text — that rule is enforced in review and revisited in Phase 2's threat model.

## Schema v1

`cycle_events` — one dated event on the cycle timeline:

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER PK AUTOINCREMENT | |
| `type` | TEXT | `CycleEventType` name. v1 only ever writes `periodStart`. |
| `date` | INTEGER (unix seconds) | **Calendar date**, time-of-day zeroed on write (`dateOnly`). "Day N" must not depend on the time a row was written. |
| `created_at` | INTEGER (unix seconds) | Audit trail — lets a later correction be told from the original entry. |

`schemaVersion = 1`. `beforeOpen` runs `PRAGMA foreign_keys = ON`.

## Migrations

`MigrationStrategy.onUpgrade` is wired but empty at v1. Every schema change:

1. Bump `AppDatabase.schemaVersion`.
2. Add an `if (from < N) { ... }` block to `onUpgrade`.
3. Add a migration test that opens at the old version, applies the upgrade, and asserts the new
   shape + that existing rows survived (`DEVELOPMENT_PLAN.md` §6.3 / §1.4).

drift's schema-snapshot tooling (`drift_dev schema dump` / `generate`) will be introduced with
the first real migration in Phase 1 so upgrades can be tested step-by-step.

## Tests

| File | Covers |
|------|--------|
| `core/test/db/app_database_test.dart` | schemaVersion, `onCreate` columns/types, `user_version`, `beforeOpen` FKs. |
| `core/test/repository/cycle_event_repository_test.dart` | log / read / watch / delete, ordering, no-op delete. |
| `core/test/db/persistence_test.dart` | write → close → reopen → still there → delete → reopen → gone (headless restart round-trip). |
| `app/test/widget_test.dart` | button → "Day 1", pre-seeded "Day N", remove → empty, **missing key → fail-safe screen**. |
| `app/integration_test/log_period_test.dart` | the same flow on a real device against the encrypted DB. Not in CI (no emulator). |

## Codegen

`core` commits drift's generated `*.g.dart`. Regenerate with:

```sh
cd core && mise exec -- dart run build_runner build
```

CI's `analyze` job regenerates and fails on any diff, so the committed output can't drift.
