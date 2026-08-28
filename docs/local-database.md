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

`beforeOpen` runs `PRAGMA foreign_keys = ON`.

## Schema v2 (p1.1)

Adds `periods` — a menstrual period as an **interval** (not paired events):

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER PK AUTOINCREMENT | |
| `start_date` | INTEGER (unix seconds) | **Calendar date**, `dateOnly` on write. |
| `end_date` | INTEGER (unix seconds), **nullable** | `null` = ongoing / end not recorded yet. |
| `created_at` | INTEGER (unix seconds) | |
| `updated_at` | INTEGER (unix seconds) | Bumped on every edit — a correction is auditable, and "fixing a past period" provably touches only that row. |

`cycle_events` is unchanged and stays as the point-in-time event log (p1.11's loss / birth /
postpartum markers). Overlap and impossible-range rules are enforced in `PeriodRepository`
(`addPeriod` / `updatePeriod` throw `PeriodValidationException`), **not** by DB constraints, so
the same rule covers every screen and stays unit-testable.

`schemaVersion = 2`.

## Migrations

`MigrationStrategy.onUpgrade` runs the steps below in order. Every schema change:

1. Bump `AppDatabase.schemaVersion`.
2. Add an `if (from < N) { ... }` block to `onUpgrade`.
3. Add a migration test that opens at the old version, applies the upgrade, and asserts the new
   shape + that existing rows survived (`DEVELOPMENT_PLAN.md` §6.3 / §1.4).

| Step | Does |
|------|------|
| `from < 2` (p1.1) | Creates `periods`; copies every `cycle_events` row of type `periodStart` into it as an open-ended period (`start_date` = `date`, `end_date` = NULL). Verified by `core/test/db/period_migration_test.dart` (real on-disk v1 file → upgrade → assert shape + row survival). |

drift's schema-snapshot tooling (`drift_dev schema dump` / `generate`) is still **not** wired up
— the v1→v2 test hand-builds the old schema. Adopting the snapshot tooling is a tracked
follow-up for the next migration (`DEVELOPMENT_PLAN.md` §9).

## Tests

| File | Covers |
|------|--------|
| `core/test/db/app_database_test.dart` | schemaVersion (2), `onCreate` columns/types for `cycle_events` **and** `periods`, `user_version`, `beforeOpen` FKs. |
| `core/test/db/period_migration_test.dart` | v1 on-disk DB → open through `AppDatabase` → `periods` created, every `periodStart` carried over, `cycle_events` intact. |
| `core/test/period/period_validation_test.dart` | impossible ranges, inclusive overlap, open-ended periods, `editingId` self-exclusion, error copy. |
| `core/test/period/drift_period_repository_test.dart` | add / watch / update / delete, ordering, validation-throws-write-nothing, **edit touches only its own row**. |
| `core/test/repository/cycle_event_repository_test.dart` | log / read / watch / delete, ordering, no-op delete. |
| `core/test/db/persistence_test.dart` | write → close → reopen → still there → delete → reopen → gone (headless restart round-trip). |
| `app/test/widget_test.dart` | empty state, dark mode, **missing key → fail-safe screen**. |
| `app/test/period/period_calendar_test.dart` | seeded period in sync across summary / calendar / history; add, edit, delete round-trip; tap a calendar day. |
| `app/test/period/period_editor_test.dart` | date fields, "has ended" toggle, valid save, overlap blocked with a clear message + Save disabled. |
| `app/integration_test/log_period_test.dart` | add → edit → delete on a real device against the encrypted DB, across a DB close/reopen. Not in CI (no emulator). |

## Codegen

`core` commits drift's generated `*.g.dart`. Regenerate with:

```sh
cd core && mise exec -- dart run build_runner build
```

CI's `analyze` job regenerates and fails on any diff, so the committed output can't drift.
