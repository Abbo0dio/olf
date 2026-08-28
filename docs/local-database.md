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

## Schema v3 (p1.2)

Adds `daily_flows` — one **per-calendar-day** flow log, keyed by the date itself:

| Column | Type | Notes |
|--------|------|-------|
| `date` | INTEGER (unix seconds), **PRIMARY KEY** | **Calendar date**, `dateOnly` on write — one row per day. |
| `intensity` | TEXT | `FlowIntensity` name (`spotting` / `light` / `medium` / `heavy`). |
| `clot_size` | TEXT, **nullable** | `ClotSize` name (`small` / `medium` / `large`), or `null`. |
| `created_at` / `updated_at` | INTEGER (unix seconds) | `setFlow` upserts on `date` and preserves `created_at`. |

Deliberately **not** linked to a `periods` row — editing or deleting a period must never
disturb what was logged for a day. There is nothing to validate (any intensity is fine, clots
optional), so `DailyFlowRepository` is plain CRUD; the UI decides when to offer logging (period
days + today).

`schemaVersion = 3`.

## Migrations

`MigrationStrategy.onUpgrade` runs the steps below in order. Every schema change:

1. Bump `AppDatabase.schemaVersion`.
2. Add an `if (from < N) { ... }` block to `onUpgrade`.
3. Add a migration test that opens at the old version, applies the upgrade, and asserts the new
   shape + that existing rows survived (`DEVELOPMENT_PLAN.md` §6.3 / §1.4).

| Step | Does |
|------|------|
| `from < 2` (p1.1) | Creates `periods`; copies every `cycle_events` row of type `periodStart` into it as an open-ended period (`start_date` = `date`, `end_date` = NULL). Verified by `core/test/db/period_migration_test.dart` (real on-disk v1 file → upgrade → assert shape + row survival). |
| `from < 3` (p1.2) | Creates `daily_flows`. Purely additive — nothing is backfilled, and existing `periods` / `cycle_events` rows are left untouched. Verified by `core/test/db/flow_migration_test.dart` (real on-disk v2 file → upgrade → assert `daily_flows` shape, period row intact, table usable). `period_migration_test.dart` also runs v1 straight through to v3. |

drift's schema-snapshot tooling (`drift_dev schema dump` / `generate`) is still **not** wired up
— both migration tests hand-build the old schema. Adopting the snapshot tooling is a tracked
follow-up (`DEVELOPMENT_PLAN.md` §9); a hand-rolled test has been enough for the two small
additive migrations so far.

## Derived data — not stored (p1.3)

**Cycles are computed from `periods` on every read, never persisted.** `core/lib/src/cycle/`
turns the period list into a `List<Cycle>` (start-to-start pairing; the newest period opens the
current, still-open cycle) plus a `CycleStats` summary — median cycle / period length, min–max
range, a coarse `CycleRegularity`, and a `hasLikelyGap` flag for intervals over ~45 days that
more likely mean a missed entry. Because nothing is stored, any period edit / delete simply
recomputes — there is **no derived row to migrate or invalidate, and no schema change in p1.3**.
There is no 28-day (or any) default: with too little history the figures are `null` and the UI
asks for more logging.

## Tests

| File | Covers |
|------|--------|
| `core/test/db/app_database_test.dart` | schemaVersion (3), `onCreate` columns/types for `cycle_events`, `periods` **and** `daily_flows`, `user_version`, `beforeOpen` FKs. |
| `core/test/db/period_migration_test.dart` | v1 on-disk DB → open through `AppDatabase` → upgraded to v3, `periods` created, every `periodStart` carried over, `cycle_events` intact, `daily_flows` present. |
| `core/test/db/flow_migration_test.dart` | v2 on-disk DB → open through `AppDatabase` → `daily_flows` created with the expected shape, existing period untouched, table usable. |
| `core/test/flow/drift_daily_flow_repository_test.dart` | `setFlow` date-only + optional clot, upsert preserves `created_at` / bumps `updated_at`, dropping a clot, `clearFlow` + no-op, `watchAll` emissions, flow survives period delete. |
| `core/test/period/period_validation_test.dart` | impossible ranges, inclusive overlap, open-ended periods, `editingId` self-exclusion, error copy. |
| `core/test/period/drift_period_repository_test.dart` | add / watch / update / delete, ordering, validation-throws-write-nothing, **edit touches only its own row**. |
| `core/test/repository/cycle_event_repository_test.dart` | log / read / watch / delete, ordering, no-op delete. |
| `core/test/cycle/cycle_derivation_test.dart` | `deriveCycles` start-to-start pairing, newest-first, single / ongoing period, order-independence, likely-gap flag (45 vs 46 days), time-of-day ignored; `CycleStats.from` median cycle/period length, regularity buckets, gaps excluded from figures but surfaced, recent-12 window, no 28-day default, recompute after an edit. |
| `core/test/db/persistence_test.dart` | write → close → reopen → still there → delete → reopen → gone (headless restart round-trip). |
| `app/test/widget_test.dart` | empty state, dark mode, **missing key → fail-safe screen**. |
| `app/test/period/period_calendar_test.dart` | seeded period in sync across summary / calendar / history; add, edit, delete round-trip; tapping a period day opens the flow quick-log, whose "Edit period dates" reaches the editor. |
| `app/test/cycle/cycle_stats_test.dart` | the cycle-stats card shows typical length + variability for a regular history; a single period shows a keep-logging nudge (no crash); the card recomputes when a period is deleted; a long gap is flagged, not treated as one cycle. |
| `app/test/period/period_editor_test.dart` | date fields, "has ended" toggle, valid save, overlap blocked with a clear message + Save disabled. |
| `app/test/flow/flow_quick_log_test.dart` | flow logged in two taps from the calendar (clots one more); a logged day renders on its calendar cell + the summary chip; the sheet preselects an existing entry and can remove it. |
| `app/integration_test/log_period_test.dart` | add → edit → delete on a real device against the encrypted DB, across a DB close/reopen. Not in CI (no emulator). |

## Codegen

`core` commits drift's generated `*.g.dart`. Regenerate with:

```sh
cd core && mise exec -- dart run build_runner build
```

CI's `analyze` job regenerates and fails on any diff, so the committed output can't drift.
