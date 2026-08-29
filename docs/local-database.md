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
| `type` | TEXT | `CycleEventType` name: `periodStart` (v1, no longer written — p1.1 moved periods to their own table), plus `pregnancyLoss` and `birth` (p1.11). Stored by enum name, so adding values is **not** a schema change. |
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

## Schema v4 (p1.5)

Adds the symptom catalogue and a per-day symptom log.

`symptom_types` — the user-editable **vocabulary** (not a dated log):

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER PK AUTOINCREMENT | |
| `name` | TEXT (1–40 chars) | Case-insensitively unique among **active** rows — enforced in `SymptomRepository`, not by DB constraint. |
| `sort_order` | INTEGER | Ascending display order; rewritten by `reorderTypes`. |
| `is_built_in` | INTEGER (0/1), default 0 | `true` for the names seeded from `kBuiltInSymptomNames`. Cosmetic only — built-ins can still be renamed / reordered / archived. |
| `archived_at` | INTEGER (unix seconds), **nullable** | Set when the user removes a symptom. **Soft delete**: the row leaves the pickers but the days it was logged on stay meaningful. |
| `created_at` / `updated_at` | INTEGER (unix seconds) | |

`daily_symptom_entries` — one row per (calendar day, symptom) that is present:

| Column | Type | Notes |
|--------|------|-------|
| `date` | INTEGER (unix seconds) | **Calendar date**, `dateOnly` on write. |
| `symptom_type_id` | INTEGER | `FOREIGN KEY → symptom_types(id) ON DELETE CASCADE`. |
| `created_at` | INTEGER (unix seconds) | |
| | | **PRIMARY KEY (`date`, `symptom_type_id`)** — toggling is idempotent; a multi-select day is just several rows. |

Presence-only in v1 — no severity or scale (see `DEVELOPMENT_PLAN.md` §9). `setSymptom(present: true)`
is insert-or-ignore, `present: false` deletes the row; there is nothing to validate, so day
logging is plain CRUD. The catalogue **is** validated (`validateSymptomName` → empty / too long /
duplicate). Entries are not linked to `periods` — like `daily_flows`, editing a period never
disturbs them.

The built-in names are seeded by `_seedBuiltInSymptoms()`, called from **both** `onCreate` (after
`createAll()`) and the `from < 4` upgrade branch, so a fresh DB and an upgraded DB start identical.

`schemaVersion = 4`.

## Schema v5 (p1.6)

Adds manual basal body temperature, cervical-mucus observations, and a key/value preferences
store. All three are keyed by `date` (except `app_settings`) and, like `daily_flows`, are **not**
linked to a `periods` row.

`bbt_entries` — one basal temperature per calendar day:

| Column | Type | Notes |
|--------|------|-------|
| `date` | INTEGER (unix seconds), **PRIMARY KEY** | **Calendar date**, `dateOnly` on write. |
| `temp_celsius` | REAL | **Canonical storage in °C.** The °C/°F choice is a display-only preference in `app_settings`. Plausible range (34–43 °C) is enforced in `BbtRepository.setTemp` (`validateCelsius`), not by a DB constraint. |
| `created_at` / `updated_at` | INTEGER (unix seconds) | `setTemp` upserts on `date` and preserves `created_at`. |

`cervical_mucus_entries` — one Billings-style observation per calendar day:

| Column | Type | Notes |
|--------|------|-------|
| `date` | INTEGER (unix seconds), **PRIMARY KEY** | **Calendar date**, `dateOnly` on write. |
| `type` | TEXT | `CervicalMucusType` name — `dry` / `sticky` / `creamy` / `watery` / `eggWhite`, ordered driest → most fertile. `creamy` and wetter are `isFertileQuality`. |
| `created_at` / `updated_at` | INTEGER (unix seconds) | Upserts on `date`, preserves `created_at`. |

`app_settings` — a tiny key/value preferences store:

| Column | Type | Notes |
|--------|------|-------|
| `key` | TEXT, **PRIMARY KEY** | Well-known keys in `SettingKeys` — `temperature_unit` (p1.6), `onboarding_complete` (p1.8), `theme_mode` and `pronouns` (p1.9). |
| `value` | TEXT | Opaque string; each caller owns its encoding. `theme_mode` ∈ `system` \| `light` \| `dark` (absent → `system`). `pronouns` is a `Pronouns` enum name (`sheHer` \| `theyThem` \| `heHim`); absent or `''` → `unspecified`, which copy resolves to they/them. |
| `updated_at` | INTEGER (unix seconds) | |

Cervical-mucus observations feed an **observed fertile-window** line on the prediction card
(`observedFertileWindow(...)` in `core/lib/src/mucus/fertile_window_signal.dart`): over the
current cycle's fertile-quality days it returns `[first fertile-quality day … last +
fertileDaysAfterOvulation]`, or `null` when there are none. The statistical `Predictor` /
`RobustPredictor` seam is **untouched** — the observed window is merged in at the display layer
only, so Phase 3's engine swap stays a drop-in.

`schemaVersion = 5`.

## Schema v6 (p1.7)

Adds a medication list, a birth-control method history, and one recurring reminder. None of
the three is linked to a `periods` row.

`medications` — the user's medication list (not a dose log):

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER, **PRIMARY KEY AUTOINCREMENT** | |
| `name` | TEXT (1–80) | Validated in `MedicationRepository` (`validateMedicationName`). |
| `dosage` | TEXT, nullable | Free text, e.g. "50 mg". Blank is stored as NULL. |
| `notes` | TEXT, nullable | Free text. Blank is stored as NULL. |
| `archived_at` | INTEGER (unix seconds), nullable | Set on removal — a **soft archive** (mirrors `symptom_types`). `NULL` = active. |
| `created_at` / `updated_at` | INTEGER (unix seconds) | `updated_at` bumped on every edit. |

`birth_control_entries` — one row per stretch of time on a method:

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER, **PRIMARY KEY AUTOINCREMENT** | |
| `method` | TEXT | `BirthControlMethod` name — `pill` / `patch` / `ring` / `injection` / `iud` / `implant` / `condom` / `other`. |
| `started_on` | INTEGER (unix seconds) | **Calendar date**, `dateOnly` on write. |
| `ended_on` | INTEGER (unix seconds), nullable | `NULL` = the current method. `switchTo` closes the previous open row the day before the new start. |
| `notes` | TEXT, nullable | |
| `created_at` / `updated_at` | INTEGER (unix seconds) | |

`reminders` — the single daily local reminder (Phase 4 generalises this table):

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER, **PRIMARY KEY AUTOINCREMENT** | |
| `kind` | TEXT, **UNIQUE** | `ReminderKind` name — only `medication` in p1.7. `UNIQUE (kind)` keeps it to one row per kind. |
| `hour` / `minute` | INTEGER | Local wall-clock time. Range enforced in `ReminderRepository.save` (`validateReminderTime`). |
| `enabled` | INTEGER (0/1) | Default `0`. |
| `created_at` / `updated_at` | INTEGER (unix seconds) | |

There is **no free-text column on `reminders`**: the notification wording is a fixed generic
string in the app layer (`reminder_scheduler.dart`), so no medication name, dosage or method
can reach a lock screen. The pure schedule model + `nextOccurrence(...)` live in
`core/lib/src/reminders/reminder_schedule.dart`; the OS-notification wrapper
(`flutter_local_notifications`) is confined to
`app/lib/src/reminders/local_notification_reminder_scheduler.dart` behind a `ReminderScheduler`
interface, with a fake in tests.

`schemaVersion = 6`.

## Migrations

`MigrationStrategy.onUpgrade` runs the steps below in order. Every schema change:

1. Bump `AppDatabase.schemaVersion`.
2. Add an `if (from < N) { ... }` block to `onUpgrade`.
3. Add a migration test that opens at the old version, applies the upgrade, and asserts the new
   shape + that existing rows survived (`DEVELOPMENT_PLAN.md` §6.3 / §1.4).

| Step | Does |
|------|------|
| `from < 2` (p1.1) | Creates `periods`; copies every `cycle_events` row of type `periodStart` into it as an open-ended period (`start_date` = `date`, `end_date` = NULL). Verified by `core/test/db/period_migration_test.dart` (real on-disk v1 file → upgrade → assert shape + row survival). |
| `from < 3` (p1.2) | Creates `daily_flows`. Purely additive — nothing is backfilled, and existing `periods` / `cycle_events` rows are left untouched. Verified by `core/test/db/flow_migration_test.dart` (real on-disk v2 file → upgrade → assert `daily_flows` shape, period row intact, table usable). `period_migration_test.dart` also runs v1 straight through to the current version. |
| `from < 4` (p1.5) | Creates `symptom_types` + `daily_symptom_entries` and seeds the built-in symptom names. Purely additive — existing `periods` / `daily_flows` / `cycle_events` rows are untouched. Verified by `core/test/db/symptom_migration_test.dart` (real on-disk v3 file → upgrade → assert both table shapes, catalogue seeded, period + flow rows intact, tables usable); `flow_migration_test.dart` and `period_migration_test.dart` also run older versions straight through and check the catalogue seeded. |
| `from < 5` (p1.6) | Creates `bbt_entries`, `cervical_mucus_entries` and `app_settings`. Purely additive — nothing is backfilled, existing rows are untouched. Verified by `core/test/db/fertility_migration_test.dart` (real on-disk v4 file with period + flow + symptom rows → upgrade → assert the three new tables exist, old rows intact, all three new repos usable). |
| `from < 6` (p1.7) | Creates `medications`, `birth_control_entries` and `reminders`. Purely additive — nothing is backfilled, existing rows are untouched. Verified by `core/test/db/meds_migration_test.dart` (real on-disk v5 file with period + settings rows → upgrade → assert the three new tables exist, old rows intact, all three new repos usable, and `reminders` rejects a second row for the same `kind`). |

drift's schema-snapshot tooling (`drift_dev schema dump` / `generate`) is still **not** wired up
— the migration tests hand-build the old schema. Adopting the snapshot tooling is a tracked
follow-up (`DEVELOPMENT_PLAN.md` §9); a hand-rolled test has been enough for the three small
additive migrations so far.

## Derived data — not stored (p1.3, p1.4)

**Cycles and predictions are computed from `periods` on every read, never persisted.**
`core/lib/src/cycle/` turns the period list into a `List<Cycle>` (start-to-start pairing; the
newest period opens the current, still-open cycle) plus a `CycleStats` summary — median cycle /
period length, min–max range, a coarse `CycleRegularity`, and a `hasLikelyGap` flag for
intervals over ~45 days that more likely mean a missed entry. `core/lib/src/prediction/` then
turns those cycles into a `CyclePrediction` (p1.4) — next-period and fertile windows as
`DateRange`s, a confidence bucket, and an `overdue` status that **never rolls the estimate
forward** — behind a `Predictor` seam so Phase 3 can swap the engine.

Because nothing is stored, any period edit / delete simply recomputes — there is **no derived
row to migrate or invalidate, and no schema change in p1.3 or p1.4**. There is no 28-day (or
any) default: with too little history the figures are `null` and the UI asks for more logging.

### Pregnancy loss / birth events (p1.11)

`pregnancyLoss` / `birth` rows in `cycle_events` are the **only** point-in-time markers still
written. They feed `deriveCycles(periods, pregnancyEvents: …)`: an interval that a loss / birth
falls inside (strictly after its `periodStart`, before the next period start) is flagged
`Cycle.isPregnancyGap`. `CycleStats` then uses **only cycles more recent than the latest such
gap** — pre-pregnancy lengths never mix into the current picture — and `RobustPredictor`
returns **no forecast at all** while the open cycle covers a loss / birth. Once a period is
logged after the event, the forecast resumes on its own from the post-event cycles.

`PregnancyRecoveryState` (`none` / `awaitingCyclesAfterLoss` / `postpartum`) drives one gentle
home banner and nothing else. **No schema change** — the two enum values are stored by name in
the existing `cycle_events.type` TEXT column, the drift codegen is unchanged, and a v1 database
opens as-is. Verified by `core/test/cycle/pregnancy_event_test.dart`,
`cycle_derivation_test.dart`, `prediction/robust_predictor_test.dart` and
`repository/cycle_event_repository_test.dart`.

## Backup & restore (p1.10)

`core/lib/src/backup/` reads every table into a **versioned plaintext `BackupDocument`**
(`{format: 'olf.backup', formatVersion, appSchemaVersion, createdAt, tables}`) and restores one
back. Rows are copied **raw** — `SELECT *` into `{column: value}` maps, parameterised `INSERT`
back — so integer `DateTime`s, `REAL` temperatures and string enum names round-trip
byte-for-byte. `BackupService.import` wipes and re-inserts **every** table in one transaction
(all-or-nothing), refuses a document whose `appSchemaVersion` ≠ the running build's, then calls
`notifyUpdates` so open streams rebuild.

`BackupCipher` wraps the document as `OLFBK1` magic + a big-endian header length + a public
JSON header (KDF params, salt, nonce, GCM tag) + **AES-256-GCM** ciphertext of the UTF-8 JSON.
The key is **PBKDF2-HMAC-SHA256(passphrase, salt)**, 210 000 iterations (stored in the header).
A wrong passphrase fails the GCM tag and raises `BackupPassphraseException` — distinct from the
`BackupFormatException` raised for a non-backup / newer-format file. This is a **separate
secret** from the at-rest SQLCipher key; backup does not touch that key.

The file is written / read through the platform document picker (`file_picker`, SAF /
`UIDocumentPicker` — **no storage permission**), behind `app/lib/src/backup/backup_gateway.dart`
so tests never load the plugin. **No schema change** — backup only touches tables that already
exist. Full detail and the deferred items are in
[`backup-and-restore.md`](backup-and-restore.md).

## Tests

| File | Covers |
|------|--------|
| `core/test/db/app_database_test.dart` | schemaVersion (6), `onCreate` columns/types for `cycle_events`, `periods`, `daily_flows`, `symptom_types`, `daily_symptom_entries` (composite PK), `bbt_entries`, `cervical_mucus_entries`, `app_settings`, `medications`, `birth_control_entries` **and** `reminders` (incl. `UNIQUE (kind)`), built-in seed order, `daily_symptom_entries` FK enforced, `user_version`, `beforeOpen` FKs. |
| `core/test/db/period_migration_test.dart` | v1 on-disk DB → open through `AppDatabase` → upgraded to the current version, `periods` created, every `periodStart` carried over, `cycle_events` intact, `daily_flows` present, symptom catalogue seeded. |
| `core/test/db/flow_migration_test.dart` | v2 on-disk DB → open through `AppDatabase` → `daily_flows` created with the expected shape, existing period untouched, later v4 migration also seeds the catalogue. |
| `core/test/db/symptom_migration_test.dart` | v3 on-disk DB → open through `AppDatabase` → `symptom_types` + `daily_symptom_entries` created with the expected shapes, catalogue seeded in order, existing period + flow rows intact, tables usable. |
| `core/test/db/fertility_migration_test.dart` | v4 on-disk DB (period + flow + symptom rows) → open through `AppDatabase` → `bbt_entries` / `cervical_mucus_entries` / `app_settings` created, old rows intact, all three new repos usable. |
| `core/test/db/meds_migration_test.dart` | v5 on-disk DB (period + settings rows) → open through `AppDatabase` → `medications` / `birth_control_entries` / `reminders` created, old rows intact, all three new repos usable, and `reminders` rejects a second row for the same `kind`. |
| `core/test/flow/drift_daily_flow_repository_test.dart` | `setFlow` date-only + optional clot, upsert preserves `created_at` / bumps `updated_at`, dropping a clot, `clearFlow` + no-op, `watchAll` emissions, flow survives period delete. |
| `core/test/symptom/symptom_validation_test.dart` | `validateSymptomName` trims, empty / too-long / case-insensitive-duplicate, rename keeps its own name, error copy. |
| `core/test/symptom/drift_symptom_repository_test.dart` | fresh DB seeded in order; `addType` append + validation throws; `renameType` incl. case change; `reorderTypes` rewrites `sort_order`; `archiveType` hides but keeps entries; archived name reusable; `watchTypes` emissions; `setSymptom` toggle idempotent on both edges, date-only; `clearDay`; `watchAllEntries` newest-first; independent of period delete. |
| `core/test/period/period_validation_test.dart` | impossible ranges, inclusive overlap, open-ended periods, `editingId` self-exclusion, error copy. |
| `core/test/period/drift_period_repository_test.dart` | add / watch / update / delete, ordering, validation-throws-write-nothing, **edit touches only its own row**. |
| `core/test/repository/cycle_event_repository_test.dart` | log / read / watch / delete, ordering, no-op delete. |
| `core/test/cycle/cycle_derivation_test.dart` | `deriveCycles` start-to-start pairing, newest-first, single / ongoing period, order-independence, likely-gap flag (45 vs 46 days), time-of-day ignored; `CycleStats.from` median cycle/period length, regularity buckets, gaps excluded from figures but surfaced, recent-12 window, no 28-day default, recompute after an edit. |
| `core/test/prediction/robust_predictor_test.dart` | `RobustPredictor` over regular / one-cycle / irregular / gap fixtures: anchor on last period start, median projection, ±1-day-floor window, fertile-window shape, `upcoming`/`dueNow`/`overdue`, **overdue never rolls forward**, confidence buckets, recompute after an edit. |
| `core/test/prediction/date_range_test.dart` | inclusive length, `contains`, time-of-day stripped, value equality, end-before-start rejected. |
| `core/test/bbt/temperature_test.dart` | °C↔°F reference points + round-trips, unit-preference storage token, `validateCelsius` plausible-range checks (incl. °F-typed-as-°C), error copy. |
| `core/test/bbt/drift_bbt_repository_test.dart` | `setTemp` date-only Celsius store, upsert preserves `created_at` / bumps `updated_at`, implausible reading rejected and nothing written, `clearTemp` + no-op, `watchAll` newest-first, independent of period delete. |
| `core/test/bbt/bbt_chart_test.dart` | `bbtChartForCycle` maps in-cycle readings to 1-based cycle days sorted, drops readings before the start or on/after the next period, current-cycle keeps everything from its start, empty history → no points. |
| `core/test/mucus/cervical_mucus_test.dart` | every type has label + description; `fertilityRank` follows enum order; `isFertileQuality` = creamy and wetter. |
| `core/test/mucus/drift_cervical_mucus_repository_test.dart` | `setMucus` date-only store, upsert preserves `created_at`, `clearMucus` + no-op, `watchAll` emissions newest-first. |
| `core/test/mucus/fertile_window_signal_test.dart` | `observedFertileWindow` → `null` with nothing fertile-quality; spans first fertile day to last + `fertileDaysAfterOvulation`; ignores observations outside `[cycleStart, today]`; a single day still yields a valid range. |
| `core/test/settings/drift_settings_repository_test.dart` | `get` null when unset, `set` round-trips + replaces, `remove` + no-op, `watch` emits current value then every change. |
| `core/test/db/persistence_test.dart` | write → close → reopen → still there → delete → reopen → gone (headless restart round-trip). |
| `app/test/widget_test.dart` | empty state, dark mode, **missing key → fail-safe screen**. |
| `app/test/period/period_calendar_test.dart` | seeded period in sync across summary / calendar / history; add, edit, delete round-trip; tapping a period day opens the flow quick-log, whose "Edit period dates" reaches the editor. |
| `app/test/cycle/cycle_stats_test.dart` | the cycle-stats card shows typical length + variability for a regular history; a single period shows a keep-logging nudge (no crash); the card recomputes when a period is deleted; a long gap is flagged, not treated as one cycle. |
| `app/test/prediction/prediction_card_test.dart` | a regular history renders next-period + fertile-window ranges with a confidence note; a late period shows the "Period check-in" (no rolled-forward date) with a *Log period start* action; editing history updates the card on the same screen; one logged period → no card yet. |
| `app/test/period/period_editor_test.dart` | date fields, "has ended" toggle, valid save, overlap blocked with a clear message + Save disabled. |
| `app/test/flow/flow_quick_log_test.dart` | flow logged in two taps from the calendar (clots one more); a logged day renders on its calendar cell + the summary chip; the sheet preselects an existing entry and can remove it. |
| `app/test/symptom/symptom_day_sheet_test.dart` | two symptoms logged in two taps from a non-period day, and they persist; reopening preselects them and unticking clears; the calendar cell + summary chip show the count; the sheet offers "Start a period" on a non-period day. |
| `app/test/symptom/manage_symptoms_test.dart` | add a custom symptom → appears as a chip; rename; remove → gone from the sheet but the historical entry survives; drag-reorder sticks. |
| `app/test/bbt/bbt_entry_test.dart` | enter a basal temperature in °F from the day sheet → stored canonically in °C, shown back in °F; an implausible reading is blocked with a message and Save disabled. |
| `app/test/bbt/bbt_chart_test.dart` | the home screen shows a per-cycle BBT chart once there are two in-cycle readings (with a summarising semantics label); no chart with only one. |
| `app/test/mucus/mucus_entry_test.dart` | pick a cervical-fluid quality → persists, tapping again clears; a fertile-quality observation surfaces a "Fertile signs (from your notes)" line on the prediction card. |
| `core/test/meds/medication_test.dart` / `core/test/meds/birth_control_test.dart` | `validateMedicationName` trim / empty / too-long; `BirthControlMethod` labels; `validateBirthControlDates` future-start + end-before-start by calendar day; error copy. |
| `core/test/meds/drift_medication_repository_test.dart` | `add` trims blanks to NULL + validates; name-ordered case-insensitive `watchActive` excludes archived; `edit` bumps `updated_at`; archive / unarchive; stream emissions. |
| `core/test/meds/drift_birth_control_repository_test.dart` | `switchTo` sets a current entry and closes the previous the day before (same-day → on its own start); future-start rejected; `stop` + no-op; `edit` range validation; `watchCurrent` emissions. |
| `core/test/reminders/reminder_schedule_test.dart` | `validateReminderTime` edges + hour-before-minute; `ReminderSchedule` equality / `copyWith`; `nextOccurrence` today-ahead / rolled-to-tomorrow / exact-now / month boundary / ignores `enabled`. |
| `core/test/reminders/drift_reminder_repository_test.dart` | `get` null before save; `save` insert-then-update keeps one row (`UNIQUE (kind)`); out-of-range time rejected and nothing written; `watch` emits null then each value. |
| `app/test/reminders/reminder_controller_test.dart` | enabling asks permission, stores an enabled row, schedules once; disabling stores + cancels; time change reschedules only when enabled; **the notification title/body contain no health words**. |
| `app/test/meds/meds_page_test.dart` | reach the screen from the home AppBar; add a medication → shows + stored; set a birth-control method → shows as current; the reminder switch schedules via the fake and persists. |
| `app/integration_test/log_period_test.dart` | add → edit → delete on a real device against the encrypted DB, across a DB close/reopen. Not in CI (no emulator). |
| `app/integration_test/log_symptoms_test.dart` | log symptoms on two days on a real device → both surface under "Recent symptoms"; cleans up after itself. Nightly only. |

## Codegen

`core` commits drift's generated `*.g.dart`. Regenerate with:

```sh
cd core && mise exec -- dart run build_runner build
```

CI's `analyze` job regenerates and fails on any diff, so the committed output can't drift.
