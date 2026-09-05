### Phase 1 — MVP core tracking (free, un-paywalled)

**Goal:** everything in `requirements.md` §1 plus the MUST-HAVE privacy
and inclusivity basics, all free. After this phase the app is a genuinely useful daily tracker.

#### p1.1 — Period logging: start/end, edit, delete, calendar view
- **Branch / worktree:** `feat/p1.1-period-logging` / `../olf-wt/p1.1`
- **Owner:** worker: phase1
- **PR:** [#9](https://github.com/Abbo0dio/olf/pull/9) (merged)
- **Depends on:** p0.4
- **Requirement refs:** §1, §9(1)
- **Goal:** Log a period with start and (optional, later) end date; see periods on a month
  calendar and a history list; edit or delete any past period. Fixing a past period does **not**
  cascade wrong data forward.
- **Acceptance criteria:**
  - Add / edit / delete period from calendar and from history list.
  - Overlapping / impossible ranges are prevented with a clear message.
  - Calendar and history stay in sync after any edit.
- **Tests required:** unit (validation, overlap rules); widget (calendar, editor); integration
  (log → edit → delete round trip).
- **Notes / detail:**
  - **Schema v1 → v2.** New `periods` table (interval entity), separate from the existing
    `cycle_events` event log:
    | Column | Type | Notes |
    |--------|------|-------|
    | `id` | INTEGER PK AUTOINCREMENT | |
    | `start_date` | INTEGER (unix s) | calendar date, `dateOnly()` on write |
    | `end_date` | INTEGER (unix s), nullable | `null` = ongoing / end not recorded yet |
    | `created_at` | INTEGER (unix s) | |
    | `updated_at` | INTEGER (unix s) | bumped on every edit; lets a correction be told from the original |
    `schemaVersion` bumped to `2`. `migration.onUpgrade` `if (from < 2)` creates `periods` and
    copies every `cycle_events` row of type `periodStart` into it (`start_date` = `date`,
    `end_date` = NULL). Covered by `core/test/db/period_migration_test.dart` (real on-disk
    v1 DB → upgrade → assert shape + row survival).
  - **Why a new table, not a `periodEnd` event type.** A period is an interval; overlap
    checking, editing and deletion are all natural on an interval row and awkward on paired
    start/end events. `cycle_events` stays as the generic point-in-time event log for p1.11
    (loss / birth / postpartum markers). `CycleEventRepository` is retained but the app no
    longer reads it. Recorded in §7.
  - **Validation lives at the repository seam** (`PeriodRepository.addPeriod` / `updatePeriod`
    both call `validatePeriod` and throw `PeriodValidationException`), so the invariant holds
    regardless of which screen calls it. Rules: `endBeforeStart`, `startInFuture`,
    `endInFuture`, `overlapsExisting` (inclusive interval intersection on date-only values; an
    end-less period is treated as open-ended for the check). "Today" is an injected clock so
    the check is deterministic and offline.
  - **No forward cascade.** p1.1 persists nothing derived, so editing one period touches only
    that row — asserted in `drift_period_repository_test.dart` (edit period A; period B's row
    is byte-for-byte unchanged). Cycle/prediction recompute-on-edit is p1.3 / p1.4.
  - **Calendar is a hand-rolled month grid** (`_MonthCalendar`), no `table_calendar` package —
    keeps the dependency-audit surface at zero. Date entry uses Flutter's built-in
    `showDatePicker`.
  - **Sync** is automatic: calendar, history and the header all watch one drift stream
    (`periodsProvider`), so any add / edit / delete refreshes every view.
  - **Follow-ups discovered** (added as TODO rows in §9): period-length sanity ceiling
    (`tooLong`); a one-tap "period ended today" quick action; adopt `drift_dev schema`
    snapshot tooling for the *next* migration.

#### p1.2 — Flow intensity, spotting, clots — one/two-tap logging
- **PR:** https://github.com/Abbo0dio/olf/pull/10 (merged)
- **Branch / worktree:** `feat/p1.2-flow-intensity` / `../olf-wt/p1.2`
- **Owner:** worker: phase1
- **Depends on:** p1.1
- **Requirement refs:** §1, §4 (fast logging), §9(10)
- **Goal:** On any period day, record flow (spotting → light → medium → heavy) and optional
  clot size, in ≤ 2 taps from the home screen.
- **Acceptance criteria:** quick-log sheet reachable in one tap; each further choice is one tap;
  values render on the calendar day cell.
- **Tests required:** widget test asserting tap-count; unit tests for the per-day model.
- **Notes / detail:**
  - **Schema v2 → v3.** New `daily_flows` table — a per-calendar-day annotation, **not**
    tied to a period row (so editing / deleting a period never cascades onto flow):
    | Column | Type | Notes |
    |--------|------|-------|
    | `date` | INTEGER (unix s), **PK** | calendar date, `dateOnly()` on write — one row per day |
    | `intensity` | TEXT enum `FlowIntensity {spotting,light,medium,heavy}` | |
    | `clot_size` | TEXT enum `ClotSize {small,medium,large}`, nullable | optional |
    | `created_at` / `updated_at` | INTEGER (unix s) | |
    `schemaVersion` → `3`. `onUpgrade` `if (from < 3)` creates `daily_flows` (additive, no
    data move). Migration test `core/test/db/flow_migration_test.dart` (real on-disk v2 → v3).
  - **`DailyFlowRepository`** (`flowOn` / `watchAll` / `setFlow` / `clearFlow`). `setFlow`
    upserts on `date` (preserves `created_at`), injectable clock. No validation rules — any
    intensity is valid, clots optional; the UI only offers the sheet on period days + today.
  - **Interaction change (from p1.1):** tapping a **period day** on the calendar now opens the
    **flow quick-log sheet** (the fast path §4 wants) instead of the period-dates editor. The
    sheet carries an "Edit period dates" button so p1.1's "edit from calendar" still holds.
    Empty-day tap and the "Add a period" button still open the period editor. The home summary
    gains a one-tap "flow" chip for today while a period is ongoing.
  - Quick-log sheet: `ChoiceChip` rows for intensity (4) and clots (4, incl. "None",
    disabled until an intensity is chosen). Each tap persists immediately (upsert) — no Save
    button, so logging flow is exactly 2 taps (open + intensity) and each further choice is 1.
  - Calendar `_DayCell` renders a 4-segment intensity bar + a clot marker, and its semantics
    label gains `", flow <level>"` / `" with <size> clots"`.

#### p1.3 — Cycle derivation & history
- **PR:** https://github.com/Abbo0dio/olf/pull/12 (merged)
- **Branch / worktree:** `feat/p1.3-cycle-derivation` / `../olf-wt/p1.3`
- **Owner:** worker: phase1
- **Depends on:** p1.1
- **Requirement refs:** §1
- **Goal:** Derive cycles (start-to-start), cycle length, period length; show a history view
  with per-cycle stats and simple variability indicators. No fixed 28-day assumption anywhere.
- **Acceptance criteria:** cycles recompute correctly after any period edit; handles gaps and
  a single logged period gracefully.
- **Tests required:** unit tests over hand-built histories incl. irregular and sparse data.
- **Notes / detail:**
  - **No schema change.** Cycles are *derived* from the `periods` table on every read, never
    stored — consistent with p1.1's "persist nothing derived, no forward cascade". Any period
    add / edit / delete just recomputes; there is no derived row to migrate or invalidate.
  - **`core/lib/src/cycle/`** (pure Dart, no Flutter):
    - **`Cycle`** — one derived cycle: `periodStart`, `periodEnd?`, `nextPeriodStart?` (`null`
      ⇒ current, still-open cycle). Getters: `lengthInDays` = `daysBetween(periodStart,
      nextPeriodStart)` (start-to-start; `null` while current), `periodLengthInDays` =
      inclusive bleed days (`null` while no end recorded), `isCurrent`, `isLikelyGap`
      (`lengthInDays > longestPlausibleCycleDays`, const **45** — a stretch that long is more
      likely a missed entry than a true cycle). Dates normalised via `dateOnly` in the ctor.
    - **`deriveCycles(Iterable<Period>) → List<Cycle>`** — sort by start, pair each period
      with the next; last becomes the current cycle. Newest-first (matches `periodsProvider`).
      Empty in → empty out; one period → one current cycle; input order irrelevant.
    - **`CycleStats.from(Iterable<Cycle>)`** — `completedCycleCount`, `typicalCycleLength`
      (median), `shortestCycleLength` / `longestCycleLength`, `typicalPeriodLength` (median),
      `regularity` (`CycleRegularity { notEnoughData, regular, mostlyRegular, irregular }` by
      max−min spread over the recent ≤ `recentWindow` (12) completed **non-gap** cycles: ≤ 4
      `regular`, ≤ 9 `mostlyRegular`, else `irregular`; < 2 → `notEnoughData`), `hasLikelyGap`.
      Likely-gap cycles are excluded from the length/variability maths but still surfaced via
      the flag. **Every figure is nullable and `null` with no history — no 28-day (or any)
      default.**
  - **`app/lib/src/cycle/`:** `cycle_providers.dart` (`cyclesProvider`, `cycleStatsProvider` —
    plain `Provider`s derived from `periodsProvider.value`; recompute on every period change),
    `cycle_format.dart` (`CycleRegularityLabel.label`, `cycleLengthNote(Cycle)`,
    `summariseStats(CycleStats)` — asks for more logging rather than inventing a number).
  - **`period_calendar_page.dart`:** new `_CycleStatsCard` between the summary and the calendar
    (typical length, min–max range, regularity, a "long gap set aside" note, or the
    "log two periods" nudge — shown once ≥ 1 period exists); each `_History` row subtitle gains
    the derived cycle length via `_HistoryRowDetail`. Heading text, empty-state copy and the
    `Edit period` / `Delete period` tooltips are unchanged, so p1.1 / integration tests still
    pass. a11y: the card is one `Semantics` container labelled with the full summary sentence.
  - **Follow-ups discovered** (added to §9): the regularity thresholds (4 / 9 days) and the
    45-day gap cutoff are heuristics — revisit against real data / p1.4's predictor. History is
    still period-first, not cycle-first; a dedicated per-cycle detail view is later work.

#### p1.4 — Prediction v1: next period + fertile window, as ranges, correctable
- **PR:** https://github.com/Abbo0dio/olf/pull/13 (merged)
- **Branch / worktree:** `feat/p1.4-prediction-v1` / `../olf-wt/p1.4`
- **Owner:** worker: phase1
- **Depends on:** p1.3
- **Requirement refs:** §1, §2, §4, §9(1) — the headline differentiator
- **Goal:** Predict next period start and the fertile window **from the user's own history**,
  always shown as a **range with a confidence note**, never a single false-precise date.
  When a period is late, the app asks sensitively ("Still no period? Log when it starts") and
  **does not roll the prediction forward silently**. Correcting a prediction (or logging the
  actual date) immediately recomputes.
- **Acceptance criteria:**
  - Predictions display as ranges; copy states uncertainty.
  - Late period → explicit check-in state, not a moving target.
  - Editing history changes the next prediction on the same screen.
  - A minimal on-device model (e.g. robust stats over recent cycles) lives in `core` behind a
    `Predictor` interface so Phase 3 can replace it.
- **Tests required:** unit tests for the predictor over regular + irregular + late-period
  fixtures; widget test for range rendering and the late-period state.
- **Notes / detail:**
  - **No schema change.** The prediction is *derived* from `cyclesProvider` (itself derived
    from `periods`) on every read — like p1.3, editing history just recomputes.
  - **`core/lib/src/prediction/`** (pure Dart):
    - **`Predictor`** — `CyclePrediction? predict({required List<Cycle> cycles, required
      DateTime today})`. The seam Phase 3's adaptive engine slots into with **no call site
      change**. Returns `null` when history is too thin (0 completed cycles) — the caller shows
      a "keep logging" state, never a fabricated date.
    - **`CyclePrediction`** — `nextPeriod` (`DateRange`), `nextPeriodExpected` (midpoint, only
      shown *with* the range), `fertileWindow` (`DateRange`), `confidence`
      (`PredictionConfidence { low, medium, high }`), `basedOnCycles`, `status`
      (`PredictionStatus { upcoming, dueNow, overdue }`), `daysPastExpected` (int?, overdue
      only).
    - **`DateRange`** — inclusive calendar-day span (`start`, `end`, `lengthInDays`,
      `contains`); the shared "show an uncertain date as a window" type (reused by p1.6).
    - **`RobustPredictor implements Predictor`** — the v1 engine. Anchor on the **last logged
      period start** (`cycles.first.periodStart`); `expected = anchor + typicalCycleLength`
      (median of recent ≤12 non-gap cycles, from `CycleStats`); window
      `[anchor + shortest, anchor + longest]` with a **±1-day floor** (`minPredictionMarginDays`)
      so even a metronomic history is never a single day. Fertile window: `expected − 14`
      (`lutealPhaseDays`, treated as fixed for v1) is estimated ovulation; window is
      `[ovulation − 5, ovulation + 1]` (`fertileDaysBeforeOvulation` / `AfterOvulation`) → a
      7-day span. **Status:** `today < earliest` → upcoming; within window → dueNow; past
      `latest` → overdue with `daysPastExpected = daysBetween(expected, today)`. **The estimate
      never rolls forward** — `expected`/`earliest`/`latest` depend only on the anchor, so a
      late period stays put and the UI shows a check-in. **Confidence:** `high` = regular +
      ≥ 3 cycles; `medium` = regular/mostly-regular + ≥ 2; else `low`; any likely gap forces
      `low`.
    - `date_math.dart` gains `addDays(d, delta)` (DST-safe calendar-day shift).
  - **`app/lib/src/prediction/`:** `prediction_providers.dart` (`predictorProvider` =
    `const RobustPredictor()`; `predictionProvider` — `Provider<CyclePrediction?>` off
    `cyclesProvider` + `DateTime.now()`), `prediction_format.dart` (compact `formatDateRange`,
    `confidenceLabel` / `confidenceNote`, `overdueHeadline` / `overdueBody` — neutral,
    non-alarming, never names a rolled-forward date).
  - **`period_calendar_page.dart`:** `_PredictionCard` between the summary and the cycle-stats
    card, shown only when `predictionProvider` is non-null. Forecast state: "Next period" +
    the range + "most likely <day>" + "Fertile window (estimate)" + the range + a confidence
    note. Overdue state: a distinct "Period check-in" card — "<n> days later than usual",
    reassuring body copy, and a **"Log period start"** button (reuses `_addPeriod`). One
    `Semantics` container with a full-sentence label. Existing screen text unchanged.
  - **Follow-ups discovered** (added to §9): the window uses raw recent min/max, not
    percentiles/MAD — Phase 3; the fertile window is anchored on the point estimate, not
    widened by the next-period uncertainty; the luteal phase is a fixed 14 days (p1.6's
    BBT/mucus inputs can refine it).

#### p1.5 — Symptom, mood & discharge logging with custom symptoms
- **PR:** https://github.com/Abbo0dio/olf/pull/14 (merged)
- **Branch / worktree:** `feat/p1.5-symptom-logging` / `../olf-wt/p1.5`
- **Owner:** worker: phase1
- **Depends on:** p0.4
- **Requirement refs:** §1, §9(10)
- **Goal:** Log cramps, mood, energy, cervical mucus / discharge, and **user-defined custom
  symptoms**, from a low-friction daily sheet. Nothing buried behind many taps.
- **Acceptance criteria:** add/rename/reorder custom symptoms; multi-select day logging;
  symptoms show on the calendar and in history.
- **Tests required:** unit (custom-symptom CRUD); widget (daily sheet); integration (log across
  several days, verify history).
- **Notes / detail:**
  - **Schema v4** — two new tables in `core/lib/src/db/tables.dart`:
    - **`SymptomTypes`** (`@DataClassName('SymptomType')`) — the symptom *catalogue*: `id`
      (autoIncrement), `name`, `sortOrder` (int, user-controlled ordering), `isBuiltIn` (bool,
      default false), `archivedAt` (nullable — **soft-delete** so historical entries stay
      meaningful and a name is never truly lost), `createdAt` / `updatedAt`
      (`withDefault(currentDateAndTime)`).
    - **`DailySymptomEntries`** (`@DataClassName('DailySymptomEntry')`) — one row per
      (day, symptom) that is present: `date` (DateTimeColumn), `symptomTypeId` (int, FK
      `REFERENCES symptom_types(id) ON DELETE CASCADE`), `createdAt`. Composite PK
      `{date, symptomTypeId}` — toggling is idempotent, multi-select is just several rows.
      Presence-only in v1 (no severity/scale).
    - **Built-ins** (`kBuiltInSymptomNames`, gender-neutral): Cramps, Headache, Chest
      tenderness, Bloating, Fatigue, Nausea, Backache, Low mood, Anxiety, Acne, Discharge.
      Seeded by `_seedBuiltInSymptoms()` called from `onCreate` (after `createAll()`) **and**
      from the `if (from < 4)` upgrade branch, with incrementing `sortOrder` and
      `isBuiltIn: true`.
  - **`core/lib/src/symptom/`** (pure Dart):
    - `symptom_validation.dart` — `SymptomTypeError { empty, tooLong, duplicate }` + `describe()`
      + `SymptomTypeException` + `validateSymptomName(name, {existingActiveNames,
      editingCurrentName})` (trim → empty; > 40 chars → tooLong; case-insensitive clash with
      another active name → duplicate). Mirrors `period_validation.dart`.
    - `symptom_repository.dart` — `abstract interface class SymptomRepository`: `watchTypes()`,
      `activeTypes()`, `addType(name)`, `renameType(id, name)`, `reorderTypes(orderedIds)`,
      `archiveType(id)`, `symptomsOn(date) → Set<int>`, `watchAllEntries()`,
      `setSymptom(date, typeId, {present})`, `clearDay(date)`.
    - `drift_symptom_repository.dart` — `DriftSymptomRepository(this._db, {now})`. Active types
      = `archivedAt IS NULL` ordered by `sortOrder`; validation throws before any write;
      `setSymptom` present → insert-or-ignore, absent → delete row; `reorderTypes` rewrites
      `sortOrder` from list index.
  - **`app/lib/src/symptom/`:** `symptom_providers.dart` (`symptomRepositoryProvider`,
    `symptomTypesProvider` / `symptomEntriesProvider` — plain non-autoDispose `StreamProvider`s,
    same pattern as `flow_providers.dart`), `symptom_format.dart` (`symptomSummary(names)`,
    day-cell fragment), `symptom_day_sheet.dart` (`showSymptomDaySheet(context, {date})` →
    modal bottom sheet; `Wrap` of multi-select `FilterChip`s; each toggle persists immediately;
    "Manage symptoms" → `ManageSymptomsPage`; non-period days also offer "Start a period on this
    day" → `showPeriodEditor(initialStart: date)` to preserve the p1.1 affordance),
    `manage_symptoms_page.dart` (`ReorderableListView` of active types; per-row Rename / Remove
    `IconButton`s; "Add symptom" dialog with inline validation).
  - **`period_calendar_page.dart`:** watch `symptomEntriesProvider` + `symptomTypesProvider` →
    `symptomCountByDay`; `_openForDay` non-period day → `showSymptomDaySheet` (period day
    unchanged — its flow sheet gains an "Add symptoms" button); `_DayCell` gains a
    `symptomCount` indicator + semantic fragment (`'$n symptom(s)'`) — days with none keep the
    exact existing label; new `_RecentSymptoms` section below `_History`.
  - **Tests:** core — `symptom/symptom_validation_test.dart`,
    `symptom/drift_symptom_repository_test.dart`, `db/symptom_migration_test.dart` (v3 → v4),
    update `db/app_database_test.dart` (schemaVersion 4 + two new `onCreate` shape tests) and
    `db/period_migration_test.dart` (→ 4 + `symptom_types` seeded). app —
    `symptom/symptom_day_sheet_test.dart` (multi-select in two taps, persist, reopen, calendar
    indicator), `symptom/manage_symptoms_test.dart` (add / rename / reorder / archive);
    nightly `integration_test/log_symptoms_test.dart` (log across several days → history).
  - **Codegen:** regenerate + commit `core/lib/src/db/app_database.g.dart`.

#### p1.6 — BBT (manual) & cervical-mucus / fertility-awareness inputs
- **PR:** https://github.com/Abbo0dio/olf/pull/15 (merged)
- **Branch / worktree:** `feat/p1.6-fertility-inputs` / `../olf-wt/p1.6`
- **Owner:** worker: phase1
- **Depends on:** p1.5
- **Requirement refs:** §1
- **Goal:** Manual basal body temperature entry with a simple chart over the cycle; structured
  cervical-mucus classification (Billings-style). Wearable BBT is Phase 8.
- **Acceptance criteria:** temperature chart per cycle; unit handling (°C/°F); mucus entries
  feed the fertile-window display from p1.4.
- **Tests required:** unit (unit conversion, chart data); widget (chart, entry).
- **Notes / detail:**
  - **Schema v5** — three new tables in `core/lib/src/db/tables.dart`, all purely additive
    (`if (from < 5) { createTable × 3 }`), `schemaVersion → 5`:
    - **`BbtEntries`** (`@DataClassName('BbtEntry')`) — one basal temperature per day: `date`
      (DateTimeColumn **PK**), `tempCelsius` (RealColumn — **canonical storage in °C**, all
      conversion is display-only), `createdAt` / `updatedAt`. Upsert on `date`, preserve
      `createdAt` (mirrors `DailyFlows`).
    - **`CervicalMucusEntries`** (`@DataClassName('CervicalMucusEntry')`) — one observation per
      day: `date` (**PK**), `type` (`textEnum<CervicalMucusType>`), `createdAt` / `updatedAt`.
      `enum CervicalMucusType { dry, sticky, creamy, watery, eggWhite }` — Billings-style,
      ordered least → most fertile.
    - **`AppSettings`** (`@DataClassName('AppSetting')`) — tiny key/value prefs store (`key`
      TextColumn **PK**, `value` TextColumn, `updatedAt`). First use: the temperature display
      unit. Reusable by p1.8 / p1.9.
  - **`core/lib/src/bbt/`** (pure Dart):
    - `temperature.dart` — `enum TemperatureUnit { celsius, fahrenheit }` (+ `symbol`),
      `celsiusToFahrenheit` / `fahrenheitToCelsius`, `convertFromCelsius` / `toCelsius`;
      `BbtError { tooLow, tooHigh }` + `validateCelsius` (plausible BBT 34.0–43.0 °C) +
      `describe()` + `BbtException`.
    - `bbt_repository.dart` / `drift_bbt_repository.dart` — `tempOn`, `watchAll`, `setTemp`
      (stores °C), `clearTemp`. Mirrors `DailyFlowRepository`.
    - `bbt_chart.dart` — `BbtChartPoint { cycleDay, date, celsius }` +
      `bbtChartForCycle(Cycle, Iterable<BbtEntry>)` mapping each in-cycle reading to its 1-based
      cycle-day index; points outside the cycle span are dropped.
  - **`core/lib/src/mucus/`** (pure Dart):
    - `cervical_mucus.dart` — `CervicalMucusTypeInfo` extension: `label`, `fertilityRank`
      (0–4), `isFertileQuality` (`creamy` and wetter).
    - `cervical_mucus_repository.dart` / `drift_cervical_mucus_repository.dart` — `mucusOn`,
      `watchAll`, `setMucus`, `clearMucus`.
    - `fertile_window_signal.dart` — **the p1.4 integration.** `observedFertileWindow(
      Iterable<CervicalMucusEntry>, {required DateTime cycleStart, required DateTime today})
      → DateRange?`: over the current cycle's fertile-quality mucus days, returns
      `[firstFertileQualityDay, lastFertileQualityDay + fertileDaysAfterOvulation]`, or `null`
      when there are none. The statistical `RobustPredictor` / `Predictor` seam is **untouched**
      (kept pristine for Phase 3); the observed window is merged in at the display layer.
  - **`core/lib/src/settings/`** — `settings_repository.dart` /
    `drift_settings_repository.dart` (`get(key)`, `set(key, value)`, `watch(key)`), plus a
    `SettingKeys` holder (`temperatureUnit`).
  - **`app/lib/src/bbt/`:** `bbt_providers.dart` (`bbtRepositoryProvider`, `bbtEntriesProvider`,
    `temperatureUnitProvider` — `StreamProvider<TemperatureUnit>` off `settingsRepository.watch`,
    default `celsius`), `bbt_format.dart` (`formatTemp(celsius, unit)`), `bbt_chart_widget.dart`
    (a self-contained `CustomPaint` line chart — **no chart package**, denylist-safe; Y axis in
    the active unit).
  - **`app/lib/src/mucus/`:** `mucus_providers.dart` (`cervicalMucusRepositoryProvider`,
    `cervicalMucusEntriesProvider`, `observedFertileWindowProvider` — `Provider<DateRange?>`
    off `cervicalMucusEntriesProvider` + `cyclesProvider`), `mucus_format.dart`.
  - **`app/lib/src/settings/settings_providers.dart`** — `settingsRepositoryProvider`.
  - **Day sheet** (`symptom_day_sheet.dart`, kept as the one daily log sheet): below the
    symptom chips, a **"Temperature & fluid"** section — a temperature row (shows the reading
    in the active unit, or "Add"; opens a small decimal-`TextField` dialog with a °C/°F toggle
    that also writes the unit pref, validated via `validateCelsius`) and a `Wrap` of
    `ChoiceChip`s for `CervicalMucusType`. Both persist immediately.
  - **`period_calendar_page.dart`:** new `_BbtCard` (shown when the current cycle has ≥ 2 BBT
    points) rendering `bbt_chart_widget`; `_PredictionCard` gains an optional
    `observedFertileWindow` — when present, the fertile-window block adds a "Fertile signs
    (from your notes)" line with that range, and the semantic label mentions it. Existing
    screen text unchanged when there are no mucus observations.
  - **Tests:** core — `bbt/temperature_test.dart`, `bbt/drift_bbt_repository_test.dart`,
    `bbt/bbt_chart_test.dart`, `mucus/cervical_mucus_test.dart`,
    `mucus/drift_cervical_mucus_repository_test.dart`, `mucus/fertile_window_signal_test.dart`,
    `settings/drift_settings_repository_test.dart`, `db/fertility_migration_test.dart` (v4 → v5),
    update `db/app_database_test.dart` (schemaVersion 5 + three new `onCreate` shape tests) and
    the other migration tests (→ 5). app — `bbt/bbt_entry_test.dart` (enter °F → stored °C →
    shown back in °F), `bbt/bbt_chart_test.dart` (chart renders for a seeded cycle),
    `mucus/mucus_entry_test.dart` (pick a type → persists; a fertile-quality pick surfaces in
    the prediction card's observed-window line).
  - **Codegen:** regenerate + commit `core/lib/src/db/app_database.g.dart`.

#### p1.7 — Medication & birth-control entries + one basic reminder
- **PR:** https://github.com/Abbo0dio/olf/pull/16 (merged)
- **Branch / worktree:** `feat/p1.7-meds-reminder` / `../olf-wt/p1.7`
- **Owner:** worker: phase1
- **Depends on:** p0.4
- **Requirement refs:** §1, §7
- **Goal:** Record medications and birth-control method (pill/patch/ring/injection). Ship **one**
  simple daily reminder (local notification, no PHI in text). The full granular notification
  system is Phase 4 and will generalise this.
- **Acceptance criteria:** method + schedule stored; a daily reminder fires; reminder text
  contains no health details.
- **Tests required:** unit (schedule model); a test around the notification scheduling wrapper.
- **Notes / detail:**
  - **Schema v6** — three new tables in `core/lib/src/db/tables.dart`, all purely additive
    (`if (from < 6) { createTable × 3 }`), `schemaVersion → 6`:
    - **`Medications`** (`@DataClassName('Medication')`) — the user's medication list: `id`
      (autoIncrement PK), `name` (TextColumn, 1–80 chars), `dosage` (TextColumn nullable, free
      text e.g. "50 mg"), `notes` (TextColumn nullable), `archivedAt` (DateTimeColumn nullable —
      soft delete, mirrors `SymptomTypes`), `createdAt` / `updatedAt`.
    - **`BirthControlEntries`** (`@DataClassName('BirthControlEntry')`) — birth-control method
      history: `id` (autoIncrement PK), `method` (`textEnum<BirthControlMethod>`), `startedOn`
      (DateTimeColumn — date-only), `endedOn` (DateTimeColumn nullable — `null` = current),
      `notes` (TextColumn nullable), `createdAt` / `updatedAt`.
      `enum BirthControlMethod { pill, patch, ring, injection, iud, implant, condom, other }`.
    - **`Reminders`** (`@DataClassName('Reminder')`) — generalisable reminder store (Phase 4
      extends it); p1.7 keeps exactly one row: `id` (autoIncrement PK), `kind`
      (`textEnum<ReminderKind>` — `{ medication }` for now), `hour` (IntColumn 0–23), `minute`
      (IntColumn 0–59), `enabled` (BoolColumn), `createdAt` / `updatedAt`. **No free-text
      column** — the notification body is a fixed generic string, so no health detail can leak.
  - **`core/lib/src/meds/`** (pure Dart):
    - `medication.dart` — `MedicationDraft` + `MedicationError { nameEmpty, nameTooLong }` +
      `describe()` + `MedicationException` + `validateMedication(name)`.
    - `birth_control.dart` — `BirthControlMethod` enum + `BirthControlMethodInfo` extension
      (`label`), `BirthControlDraft`, `BirthControlError { startInFuture, endBeforeStart }` +
      `describe()` + `BirthControlException` + `validateBirthControl({startedOn, endedOn, today})`.
    - `medication_repository.dart` / `drift_medication_repository.dart` — `watchActive`
      (archivedAt IS NULL, ordered by name), `add`, `update`, `archive`, `unarchive`.
    - `birth_control_repository.dart` / `drift_birth_control_repository.dart` — `watchAll`,
      `current` (latest row with `endedOn IS NULL`), `add`, `update`, `end`, `delete`.
  - **`core/lib/src/reminders/`** (pure Dart — **the "schedule model"**):
    - `reminder_schedule.dart` — `enum ReminderKind { medication }`;
      `class ReminderSchedule { final ReminderKind kind; final int hour; final int minute;
      final bool enabled; }` with `ReminderError { hourOutOfRange, minuteOutOfRange }` +
      `describe()` + `ReminderException` + `validateReminderTime(hour, minute)`; and the pure
      function `DateTime nextOccurrence(ReminderSchedule, {required DateTime from})` — the next
      wall-clock `DateTime` at `hour:minute` at or after `from` (today if still ahead, else
      tomorrow). This is the unit-tested schedule model.
    - `reminder_repository.dart` / `drift_reminder_repository.dart` — `watch(kind)` /
      `get(kind)` (the single row or `null`), `save(ReminderSchedule)` (upsert on `kind`).
  - **`app/lib/src/reminders/`:**
    - `reminder_scheduler.dart` — `abstract interface class ReminderScheduler {
      Future<bool> ensurePermission(); Future<void> scheduleDaily(ReminderSchedule);
      Future<void> cancel(ReminderKind); }`. Fixed notification copy lives here as
      `const reminderTitle = 'olf'` / `const reminderBody = 'Time for your daily check-in.'` —
      **no medication name, dosage, method, or the word "medication" appears in either.**
    - `local_notification_reminder_scheduler.dart` — real impl over
      **`flutter_local_notifications`** + **`timezone`** + **`flutter_timezone`** (new deps —
      none denylisted; none are ad/analytics/crash SDKs). Lazy plugin init; `zonedSchedule`
      with `DateTimeComponents.time` for daily repeat; a stable notification id per
      `ReminderKind`. All plugin access is behind this class so `flutter test` never loads a
      platform channel.
    - `reminder_providers.dart` — `reminderSchedulerProvider` (overridable),
      `reminderRepositoryProvider`, `medicationReminderProvider`
      (`StreamProvider<ReminderSchedule?>`), and a `ReminderController` that writes the row and
      calls the scheduler (`scheduleDaily` on enable / time change, `cancel` on disable).
  - **`app/lib/src/meds/`:** `meds_providers.dart` (`medicationRepositoryProvider`,
    `medicationsProvider`, `birthControlRepositoryProvider`, `currentBirthControlProvider`),
    `meds_page.dart` — a **Medications & reminders** screen reached from a new `AppBar`
    action on `HomePage` (`Icons.medication_outlined`, tooltip "Medications & reminders"):
    - "Daily reminder" — `SwitchListTile` (enabled) + a time row opening `showTimePicker`;
      both persist immediately and drive `ReminderController`; enabling first calls
      `ensurePermission()`.
    - "Birth control" — current method (or "None set") + an edit sheet (method
      `DropdownButton` / chips + start-date picker).
    - "Medications" — list of active meds; add / edit / archive via a small form sheet.
  - **Manifest:** `flutter_local_notifications` needs Android `<uses-permission>` entries —
    `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`,
    `VIBRATE` — each with an adjacent `<!-- audited: … Reviewed 2026-08-29 by worker: phase1. -->`
    comment so the dependency-audit CI passes. iOS init requests alert/badge/sound perms.
  - **`app/lib/main.dart`:** `main()` becomes `async` — `WidgetsFlutterBinding.ensureInitialized()`
    then best-effort `LocalNotificationReminderScheduler` init (guarded; failure is non-fatal
    and the app still runs offline).
  - **Tests:** core — `meds/medication_test.dart`, `meds/birth_control_test.dart`,
    `meds/drift_medication_repository_test.dart`,
    `meds/drift_birth_control_repository_test.dart`,
    `reminders/reminder_schedule_test.dart` (**schedule model** — validation +
    `nextOccurrence` across the day boundary / exact-now), `reminders/drift_reminder_repository_test.dart`,
    `db/meds_migration_test.dart` (v5 → v6), update `db/app_database_test.dart`
    (schemaVersion 6 + three `onCreate` shape tests) and the other migration tests (→ 6).
    app — `reminders/reminder_controller_test.dart` (**test around the wrapper**, with a
    `FakeReminderScheduler`: enabling schedules a daily reminder at the chosen time; disabling
    cancels; changing the time reschedules; the scheduled title/body are the fixed generic
    strings and contain no medication/method text), `meds/meds_page_test.dart` (add a
    medication → shows; set a birth-control method → shows; reminder switch state persists).
  - **Codegen:** regenerate + commit `core/lib/src/db/app_database.g.dart`.

#### p1.8 — Anonymous-by-default, local PIN lock, disclaimers, first-run privacy explainer
- **PR:** https://github.com/Abbo0dio/olf/pull/17 (merged)
- **Branch / worktree:** `feat/p1.8-pin-disclaimers` / `../olf-wt/p1.8`
- **Owner:** worker: phase1
- **Depends on:** p0.4
- **Requirement refs:** §3, §6, §9(8)
- **Goal:** No account required to use anything. Optional numeric PIN to open the app. First-run
  screen plainly explains: data is on your device, HIPAA does not apply here, this is not
  medical advice / not a contraceptive. Biometric unlock, decoy screen, and scheduled deletion
  are **Phase 2**.
- **Acceptance criteria:** fresh install is fully usable with zero personal data entered; PIN
  gate works and is optional; disclaimer copy reviewed against §6.
- **Tests required:** widget/integration for the PIN gate; content test that disclaimer strings
  are present on first run.
- **Notes / detail:**
  - **No schema change.** The one new persisted bit — the `onboarding_complete` flag — reuses
    the p1.6 `app_settings` key/value store (`SettingKeys.onboardingComplete`). The PIN secret
    lives in the platform secure enclave, not the DB.
  - **`core/lib/src/security/`** (pure Dart, new `crypto` direct dep — Dart-team package, not
    ad/analytics):
    - `pin.dart` — `validatePin` (4–12 digits, digits only), `PinError` + `describe()` +
      `PinException`; `PinCredential { saltBase64, hashBase64, iterations }` with a JSON
      `toStorageString` / `fromStorageString` round-trip; `generatePinSalt` (16 random bytes),
      `derivePinCredential` / `hashPin` (iterated HMAC-SHA256, `defaultPinIterations = 30000`),
      `verifyPin` (constant-time compare). **Documented as a UI-level gate, not a crypto
      boundary** — the PIN does not wrap the DB key in Phase 1.
    - `pin_store.dart` — the `PinStore` interface (mirrors `DatabaseKeyStore`); **presence of a
      stored credential is the "lock is on" signal**, no separate flag.
  - **`app/lib/src/security/`:** `secure_storage_pin_store.dart` (`PinStore` over
    `flutter_secure_storage`, same options as `SecureStorageKeyStore`); `pin_providers.dart`
    (`pinStoreProvider`, `pinCredentialProvider` `FutureProvider`, `pinIsSetProvider`,
    `sessionUnlockedProvider` `StateProvider`, and a `PinController` for set / change / clear /
    verify); `pin_unlock_screen.dart` (numeric entry, wrong-PIN message, no lockout yet).
  - **`app/lib/src/onboarding/`:** `disclaimers.dart` (the four disclaimer points as named
    consts — data on this device / no sale, HIPAA doesn't apply, not medical advice, not a
    contraceptive — reviewed against §3 / §6); `onboarding_providers.dart`
    (`firstRunDoneProvider` off `app_settings`); `first_run_screen.dart` (the explainer +
    optional PIN opt-in; "continue" writes the flag and enters the app).
  - **`app/lib/src/app_gate.dart`** — new `MaterialApp.home`. Order: DB opens → first-run
    explainer (once) → PIN lock (if set and session locked) → `HomePage`. A DB error falls
    through to `HomePage` (which owns the fail-safe screen). Re-locks on
    `AppLifecycleState.paused` / `hidden` via `AppLifecycleListener`.
  - **`app/lib/src/settings/settings_page.dart`** — new, reached from a home `AppBar` gear
    icon. For now just an "App lock" switch (set / change / remove the PIN) so the lock is
    genuinely optional and reversible without reinstalling; p1.9 adds theme + pronoun here.
  - **Test harness:** `pumpOlf` gains `onboarded` (default `true` → skips the explainer) and
    `pinStore` (default empty `FakePinStore` → no lock) so every existing widget test is
    unaffected; the new tests opt in.
  - **Tests:** core — `security/pin_test.dart` (validation, hashing determinism + salt/iter
    sensitivity, credential round-trip, verify). app — `onboarding/first_run_test.dart` (every
    disclaimer point shown; continue-with-no-PIN → usable + flag persisted; PIN opt-in stores a
    credential; mismatch rejected), `security/pin_gate_test.dart` (no PIN → no gate; PIN → lock
    screen, wrong rejected, right unlocks), `settings/settings_page_test.dart` (toggle lock on
    → credential stored; off → cleared).
  - **Docs:** `docs/privacy-and-lock.md` (new), `app_settings` key row in
    `docs/local-database.md`.

#### p1.9 — Dark mode + gender-neutral, discreet theme baseline
- **PR:** [#18](https://github.com/Abbo0dio/olf/pull/18) — merged (squash → `fccfc37`)
- **Branch / worktree:** `feat/p1.9-theme-baseline` / `../olf-wt/p1.9`
- **Owner:** worker: phase1
- **Depends on:** p0.2
- **Requirement refs:** §4, §9(7)
- **Goal:** A neutral, non-pink, non-gendered default theme with full light/dark support and an
  optional pronoun setting used in copy. Sweep all existing strings for "hey girl"-style copy.
- **Acceptance criteria:** every screen to date renders correctly in both themes; a copy
  lint/checklist for gendered language is added and passes.
- **Tests required:** golden tests (light + dark) for main screens; a string-audit test.
- **Notes / detail:**
  - **No schema change.** Two new `app_settings` keys via `SettingKeys`: `theme_mode`
    (`system` / `light` / `dark`) and `pronouns` (a `Pronouns` name). Both reuse the p1.6
    key/value store.
  - **`app/lib/src/theme/`:** `olf_theme.dart` — the inline `ThemeData` from `main.dart`
    extracted and hardened into `olfTheme(Brightness)`: the existing neutral sage seed
    (`0xFF4C6B5A` — deliberately not pink/gendered), Material 3, a shared text/`CardTheme`
    baseline so light and dark match. `theme_providers.dart` — `themeModeProvider`
    (`StreamProvider<ThemeMode>` off `settingsRepository.watch(theme_mode)`, `system` until the
    DB is open / the user chooses), plus a setter on the settings repo.
  - **`main.dart`:** `OlfApp` becomes a `ConsumerWidget`, watches `themeModeProvider`, and
    passes `olfTheme(light)` / `olfTheme(dark)` + the chosen `themeMode`.
  - **`core/lib/src/personalization/pronouns.dart`** (pure Dart): `enum Pronouns
    { unspecified, sheHer, theyThem, heHim }`; `PronounForms { subject, object,
    possessiveDeterminer, possessivePronoun, reflexive }`; `formsFor(Pronouns)` —
    `unspecified` resolves to they/them so default copy is correct with nothing set;
    `describePronouns` (`'they / them'` …); `pronounsToStorage` / `fromStorage`;
    `pronounExampleSentence(Pronouns)` — a short sentence built from the forms, the first
    concrete consumer of the setting.
  - **`app/lib/src/settings/settings_page.dart`** (grows): an **Appearance** section — a
    `SegmentedButton` for System / Light / Dark — and a **Pronouns** row (`unspecified` /
    `they/them` / `she/her` / `he/him`) with a live `pronounExampleSentence` preview. Both
    persist immediately.
  - **`app/lib/src/personalization/personalization_providers.dart`:** `pronounsProvider`
    (`StreamProvider<Pronouns>` off `settings`, default `unspecified`).
  - **Inclusive-language sweep:** existing copy is already second-person / neutral (audited —
    no "hey girl" / "ladies" / assumed-partner language). p1.9 **locks that in**:
    `docs/inclusive-language.md` (the checklist) + `app/test/copy/inclusive_language_test.dart`
    — scans every string literal under `app/lib/**` and `core/lib/**` against a denied-phrase
    list and fails on a match.
  - **Tests:** app — `theme/theme_render_test.dart` (each main screen — empty calendar,
    calendar with data, day-log sheet, meds, settings, first-run, PIN unlock — pumps in both
    `olfTheme(light)` and `olfTheme(dark)` with **no exception and no `RenderFlex` overflow**,
    and `Theme.of(context).brightness` matches); `settings/settings_page_test.dart` grows
    (switch theme mode → persisted + `MaterialApp.themeMode` follows; pick pronouns → persisted
    + preview updates); `copy/inclusive_language_test.dart`. core —
    `personalization/pronouns_test.dart` (`formsFor` incl. `unspecified`→they, storage
    round-trip, example sentence per value).
  - **Pixel goldens** (`matchesGoldenFile`) are **deferred** — they need golden CI infra +
    pinned fonts to not be flaky on the ubuntu runner; the render tests above cover the
    acceptance criterion ("renders correctly in both themes"). Noted in §9.

#### p1.10 — Local backup & restore (encrypted export / import)
- **PR:** [#19](https://github.com/Abbo0dio/olf/pull/19) — merged (squash → `b53e6da`)
- **Branch / worktree:** `feat/p1.10-backup-restore` / `../olf-wt/p1.10`
- **Owner:** worker: phase1
- **Depends on:** p1.1–p1.7 (whatever schema exists)
- **Requirement refs:** §4, §9(11)
- **Goal:** Export all data to a single encrypted file the user controls; import it back on the
  same or a new device. This is the data-loss safety net and a store-release prerequisite.
- **Acceptance criteria:** export → wipe → import reproduces all data exactly; format is
  versioned; wrong passphrase fails cleanly.
- **Tests required:** integration (full round trip); unit (serializer versioning).
- **Notes / detail:**
  - **No schema change.** Backup reads/writes existing tables only.
  - **`core/lib/src/backup/`** (pure Dart):
    - `backup_document.dart` — the versioned, still-plaintext shape:
      `{format: 'olf.backup', formatVersion: 1, appSchemaVersion, createdAt, tables}`.
      `BackupDocument.fromJson` validates and throws `BackupFormatException` on a wrong
      `format`, a missing/non-int version, or a version **newer** than this build; an older
      version falls through to a (currently empty) forward-migration path.
      `backupFormatVersion` is separate from the DB `schemaVersion`, which travels alongside.
    - `backup_service.dart` — `BackupService(AppDatabase)`. `export()` does `SELECT *` per
      table into raw `{column: value}` maps (so integer `DateTime`s and string enum names
      round-trip byte-for-byte); `import(doc)` wipes + re-inserts **every** table in one
      transaction (all-or-nothing), parents before children for the one FK, then
      `notifyUpdates` so open streams rebuild. Refuses a backup whose `appSchemaVersion` ≠
      this build's. A `tableOrder` constant covers the whole schema; a test fails if a new
      table is added without updating it.
    - `backup_cipher.dart` — `BackupCipher.seal/open`. Container: `OLFBK1` magic, 4-byte BE
      header length, JSON header (KDF params + salt + nonce + GCM tag, all public), then
      AES-256-GCM ciphertext of the UTF-8 JSON. Key = PBKDF2-HMAC-SHA256(passphrase, salt),
      210k iterations (stored in the header, so it can rise later). Wrong passphrase →
      `SecretBoxAuthenticationError` → `BackupPassphraseException` (distinct from
      `BackupFormatException`). `validateBackupPassphrase` (≥ 8 chars). Uses the new
      `cryptography` package (pure Dart, no ad/analytics surface) added to `core`.
  - **`app/lib/src/backup/`:**
    - `backup_gateway.dart` — `BackupFileGateway` interface (`writeBackup` / `pickBackup`) +
      `FilePickerBackupFileGateway` using `file_picker` (SAF / `UIDocumentPicker`, **no**
      storage permission). The one platform touch, behind a seam like p1.7's scheduler.
    - `backup_controller.dart` — `BackupController` wires service + cipher + gateway; every
      expected failure (cancel, wrong passphrase, wrong file) is a `RestoreResult` /
      `ExportResult` value, only bugs throw. Suggests `olf-backup-YYYY-MM-DD.olfbackup`.
    - `backup_providers.dart` — `backupControllerProvider` (data-branch only),
      `backupFileGatewayProvider` (overridden in tests).
    - `backup_page.dart` — `BackupPage`: intro copy, "Create an encrypted backup" (passphrase
      + confirm dialog), "Restore from a backup file" (replace-everything warning → file →
      passphrase). Reached from a new **Data** row in Settings. Busy spinner; on restore,
      pops to home.
  - **Tests:** core — `backup_document_test.dart` (versioning: rejects newer, non-int,
    wrong-format, malformed tables/date; round-trips), `backup_cipher_test.dart` (seal/open;
    wrong passphrase + tampered bytes → `BackupPassphraseException`; garbage/truncated →
    `BackupFormatException`; passphrase length), `backup_service_test.dart` (`export` → fresh
    db → `import` reproduces every table exactly; replace-not-merge; schema-version mismatch
    refused; failed insert rolls back; `tableOrder` == schema). app — `backup_controller_test.dart`
    (round trip + all result branches through a fake gateway), `backup_flow_test.dart` (widget:
    Settings → Backup page → export → wipe → restore → data back, pops home; wrong passphrase
    reported).
  - **Deferred:** the real `file_picker` path (SAF dialogs) is exercised only manually /
    on-device, same as p1.7's notification plugin — CI covers the `BackupFileGateway` seam
    with a fake. gzip of the JSON before encryption; a Phase 2 tie-in so scheduled deletion
    also scrubs old backups; deriving the DB key from the same passphrase. See §9.

#### p1.11 — Explicit pregnancy-loss, birth, and postpartum events (minimal)
- **PR:** [#20](https://github.com/Abbo0dio/olf/pull/20) (merged)
- **Branch / worktree:** `feat/p1.11-loss-birth-events` / `../olf-wt/p1.11`
- **Owner:** worker: phase1
- **Depends on:** p1.3
- **Requirement refs:** §2, §9(3), Prioritized Matrix (MUST-HAVE)
- **Goal:** Let the user log a miscarriage / pregnancy loss, a "gave birth" event, and enter a
  postpartum state, so the cycle engine **stops treating the gap as one long normal cycle**.
  Full pregnancy/TTC/postpartum *modes* are Phase 7 — this is the event + engine handling only.
- **Acceptance criteria:** each event type is loggable with a date; cycle derivation and
  predictions exclude/adjust around it; sensitive, non-clinical copy.
- **Tests required:** unit tests: loss/birth event breaks the cycle chain correctly; prediction
  does not produce nonsense across the event.
- **Notes / detail:**
  - **No schema change.** The dormant `cycle_events` table (kept since v1 for exactly this)
    gets two new `CycleEventType` values — `pregnancyLoss`, `birth` — stored by enum name in
    the existing TEXT column. drift codegen is byte-identical; a v1 database opens as-is.
  - **`core/lib/src/cycle/pregnancy_event.dart`** (pure Dart): `enum PregnancyEndKind
    { loss, birth }` + `.eventType` / `pregnancyEndKindOf` mapping; `class PregnancyEvent`
    (id, kind, date) + `fromRow`; `mostRecentPregnancyEnd`; `enum PregnancyRecoveryState
    { none, awaitingCyclesAfterLoss, postpartum }` + `pregnancyRecoveryState({events,
    periods})` — `none` again as soon as a period starts after the most recent end.
  - **`Cycle`** gains `interruptedBy` (a `PregnancyEndKind?`) + `isPregnancyGap`.
    **`deriveCycles(periods, {pregnancyEvents})`**: an interval a loss / birth falls inside
    (strictly after its start, before the next start) is marked; newest event wins.
    **`CycleStats.from`** uses only cycles *newer than the latest pregnancy gap*
    (`takeWhile(!isPregnancyGap)`), so pre-pregnancy lengths never mix in.
    **`RobustPredictor.predict`** returns `null` while `cycles.first.isPregnancyGap` — no
    forecast projected across the event; it resumes on its own from post-event cycles.
  - **`CycleEventRepository`** gains `logPregnancyEnd` / `watchPregnancyEvents` /
    `pregnancyEvents` (reusing `deleteEvent`); `DriftCycleEventRepository` implements.
  - **app:** `pregnancy/pregnancy_providers.dart` (`cycleEventRepositoryProvider`,
    `pregnancyEventsProvider`, `pregnancyRecoveryStateProvider`,
    `mostRecentPregnancyEndProvider`); `cyclesProvider` now feeds `deriveCycles` the events;
    `pregnancy/pregnancy_events_page.dart` — a dedicated **Settings → Cycle → Pregnancy loss &
    birth** screen (list + add via a kind/date sheet + remove); a gentle `_PregnancyStatusCard`
    on the home body while `PregnancyRecoveryState != none`. Copy is neutral / non-clinical
    ("Pregnancy loss", "Birth"); passes the p1.9 inclusive-language lint.
  - **Tests:** core — `cycle/pregnancy_event_test.dart` (mapping, `mostRecentPregnancyEnd`,
    `pregnancyRecoveryState`); `cycle_derivation_test.dart` +group (gap marking, `CycleStats`
    ignores the far side, no-events = unchanged); `robust_predictor_test.dart` +group (no
    forecast across a birth/loss; resumes on post-event cycles, not the old ones);
    `repository/cycle_event_repository_test.dart` +group. app —
    `pregnancy/pregnancy_events_test.dart` (record → remove), `pregnancy/pregnancy_home_test.dart`
    (birth pauses the forecast + shows the note; note clears after a period).
  - **Deferred:** no in-calendar affordance to log an event on a tapped day (Settings only);
    `PregnancyRecoveryState` flips straight to `none` on the first post-event period rather than
    easing over a few cycles; no pregnancy / TTC / postpartum *modes* (Phase 7); the loss / birth
    day is not drawn on the month calendar. See §9.

#### p1.12 — Cycle phase wheel: circular, color-coded phase view with a correctable indicator
- **Frozen:** DONE (2026-09-05) · PR #64 · squash `f9780bd` — out-of-band Phase 1 sibling (cycle-phase wheel), merged during Phase 6; not a Phase 1 gate item.
- **Depends on:** none (built on the existing `Cycle` / `CyclePrediction`
  data — no new domain engine)
- **Branch / worktree:** `feat/p1.12-cycle-wheel` / `../olf-wt/p1.12`
- **PR:** [#64](https://github.com/Abbo0dio/olf/pull/64)
- **Owner:** worker: phase1
- **Requirement refs:** §1 (Stage 1 — correctable cycle info, never a fabricated date), §4
  (UX/design), §8 (accessibility — WCAG: color is never the only signal, contrast, tap targets,
  text-scaling; must go through the p5.1 test harness like every other screen)
- **Goal:** a glanceable circular visualization on the home/calendar screen — the cycle divided
  into color-coded phase arcs (menstrual / follicular / ovulatory / luteal) with a marker showing
  today's position — that the user can correct with a tap, the same way every other reading in
  this app is correctable.
- **Design (orchestrator, 2026-09-05 — user-requested):**
  - **No new predictor.** Phase boundaries are a pure **derivation** from data the app already
    computes: the current `Cycle` (`periodStart`/`periodEnd`) and the current `CyclePrediction`
    (`nextPeriod`, `fertileWindow`, `nextPeriodExpected`). Menstrual = the logged/ongoing period;
    follicular = period end → `fertileWindow.start`; ovulatory = `fertileWindow`; luteal =
    `fertileWindow.end` → `nextPeriodExpected`. New pure function in `core`
    (`core/lib/src/cycle/cycle_phase.dart`, house style — no `DateTime.now()`, `today` injected),
    unit-tested standalone. **Personalized, not generic**: arc widths reflect the user's own
    predicted phase lengths, not fixed textbook proportions — consistent with the Phase 3 "no
    false precision" gate. When there's no current cycle to anchor on (nothing logged yet, or the
    latest cycle `isLikelyGap`/`isPregnancyGap`), the function returns `null` and the widget shows
    an honest "log a period to see this" placeholder ring — never a fabricated phase.
  - **"Correctable" = the existing quick-log entry points, not a new mechanism.** Tapping the
    wheel opens the same today flow-quick-log / symptom-day-sheet actions `_Summary` already
    wires up (`onLogTodayFlow` / `onLogTodaySymptoms`) — logging or editing today's entry is what
    corrects the wheel, exactly like it already corrects the prediction card and triggers the
    Phase 3 correction-notice loop. No parallel "tell us we're wrong" UI to build or maintain.
  - **Placement:** new widget at the top of `period_calendar_page.dart`'s scroll column, above
    `_Summary` — the primary at-a-glance visual; the existing text `_PredictionCard` stays for
    the detailed dates/confidence/basedOnCycles readout, unchanged.
  - **Accessibility (non-negotiable, ties into the Phase 5 harness):** phase is never conveyed by
    color alone — each arc/segment also carries a text label reachable by screen readers, and the
    center readout states the phase name and day-in-phase as text. Contrast checked against
    `core`'s `contrast.dart` (WCAG AA) for both themes; tap target ≥48dp; add this screen state to
    `app/test/support/screen_nav.dart`'s `screenSurfaces` so it rides the existing guideline /
    label / contrast / keyboard-nav / text-scaling sweep — do not hand-roll a separate a11y test
    path for it. Respect `reduceSpokenDetail` (p5.3): the semantic label redacts to a generic form
    when it's on, same as every other reading on this screen; visible text is unaffected.
  - **No new dependency** — drawn with `CustomPainter`/`Canvas.drawArc`, standard Flutter, no
    chart package. **No schema change** — purely derived, nothing new stored.
- **Acceptance criteria:**
  - `core/lib/src/cycle/cycle_phase.dart` — pure `currentCyclePhase({cycle, prediction, today})`
    (or equivalent), returns phase kind + day-in-phase + the boundary dates used, `null` when
    there's no safe anchor; exported from `olf_core.dart`.
  - New `app` widget (e.g. `app/lib/src/cycle/cycle_wheel.dart`) rendering the four-phase ring +
    today marker + center text readout + the `null` placeholder state; wired into
    `period_calendar_page.dart` above `_Summary`.
  - Tap anywhere on the wheel reaches the same today quick-log / symptom-sheet actions as
    `_Summary`.
  - Added to `screen_nav.dart`'s surface inventory; passes the existing guideline, semantics-label,
    contrast, keyboard-nav, and text-scaling (to 2.0×) sweeps with no skips.
  - `reduceSpokenDetail` redacts the wheel's semantic label; visible text unchanged.
- **Tests required:** `core/test/cycle/cycle_phase_test.dart` (each phase, the boundary days,
  the gap/no-anchor → `null` case, a pregnancy-gap cycle → `null`); an `app` widget test for the
  wheel (renders each phase, tap reaches quick-log, `null` state renders the placeholder,
  `reduceSpokenDetail` redaction); the four Phase 5 sweep suites pick it up via `screen_nav.dart`
  with no new skips. Existing core + app suites stay green.
- **Notes / detail:** worker picks the exact visual treatment (colors, stroke width, marker
  shape) within the theme's existing palette and the WCAG AA contrast constraint above — no need
  to ask back on cosmetic choices. If the four-arc geometry can't be made cleanly proportional
  when a phase length estimate is very short (e.g. a compressed follicular phase), a sane minimum
  arc width for legibility is fine; note the tradeoff in the build log rather than treating it as
  a §5 item.
- **Build detail (worker: phase1):**
  - **`core/lib/src/cycle/cycle_phase.dart`** — `CyclePhaseKind` (menstrual/follicular/ovulatory/
    luteal) + `.label`; `CyclePhaseSegment` (kind, start, end; `lengthInDays` floors at 0 rather
    than going negative; `contains(day)`); `CyclePhase` (today, the 4 segments in cycle order,
    `currentIndex` → `.current`/`.dayInPhase`). `currentCyclePhase({cycle, prediction, today})`:
    menstrual end = `cycle.periodEnd ?? today` (an open period draws through today rather than
    guessing an end); follicular = menstrual-end+1 → `fertileWindow.start`-1; ovulatory =
    `fertileWindow`; luteal = `fertileWindow.end`+1 → `max(nextPeriodExpected, lutealStart)` (a
    1-day floor if the estimate is degenerate). Returns `null` for no cycle/prediction, a likely
    or pregnancy gap cycle, a future-dated period, or a fertile window that doesn't actually sit
    after the period (a malformed estimate) — never a fabricated phase. An overdue today (past
    every segment) lands on `luteal` (`indexWhere` → `-1` fallback) with `dayInPhase` honestly
    exceeding `lengthInDays`, rather than inventing a fifth phase.
  - **`app/lib/src/cycle/cycle_wheel.dart`** — `CycleWheel(phase, reduceSpoken, onTap)`. Ring:
    `CustomPaint`/`Canvas.drawArc`, 180dp diameter, one `InkWell(customBorder: CircleBorder())`
    (≥48dp tap target, comfortably) wrapped in an outer `Semantics(button: true, label:, onTap:)`
    with the visual subtree `ExcludeSemantics`'d so a screen reader sees exactly one node. Colors:
    menstrual→`primary`, follicular→`secondary`, ovulatory→`tertiary`, luteal→`outline` — all four
    already ≥3:1 (component) or ≥4.5:1 (text) against `surface` in both themes (verified; added
    `secondary/surface` to `theme_contrast_test.dart`, the other three were already checked). A
    zero/near-zero-length phase (e.g. a compressed follicular estimate) gets a 6%-of-circle minimum
    sweep, the whole ring renormalized back to 360° — a drawing trade-off (shrinks the other arcs a
    little), day counts in the caption are never adjusted. Today's marker: an `onSurface` dot on a
    `surface`-colored halo, so it reads against any of the four arc colors by construction (the
    halo color already clears contrast against every arc color). Caption below the ring (never
    overlaid on it, so 2.0× text scaling just grows the column — no `RenderFlex` overflow risk):
    phase name + "Day N". Placeholder (`phase == null`): a plain `surfaceContainerHighest` ring +
    "Log a period to see this", still tappable → the same `onTap`. Non-reduced semantic label spells
    out all four segments' date spans as text (WCAG "never color-only", reachable by screen
    readers); reduced label is generic ("Cycle phase available. Tap to log today's flow.").
  - **`period_calendar_page.dart`** — one `CyclePhase? cyclePhase = currentCyclePhase(cycle:
    currentCycle, prediction:, today:)` computed inline (same pattern as the existing
    `bbtPoints`/`currentCycle` locals); `CycleWheel` placed above `_Summary`, `onTap` reuses the
    exact `showFlowQuickLog(context, date: today)` closure `_Summary.onLogTodayFlow` uses — tapping
    the wheel is not a second, parallel implementation of "log today".
  - **`app/test/support/screen_nav.dart`** — new `_seedRecentCycle` (six periods, a regular 28
    days apart, most recent starting 20 days ago via the existing `_daysAgo` helper) and a new
    surface `'period_calendar_page — cycle wheel (active phase)'`. The existing `_seedHistory`
    surface uses fixed 2025 dates that are stale by now, so its cycle is always a likely-gap and
    the wheel there only ever shows its placeholder — this new surface is `_daysAgo`-relative so
    "today" always lands inside a real phase, and the sweep actually exercises the ring's
    arcs/marker/label, not just the placeholder. 17 surfaces total now (comment updated).
  - **`app/test/a11y/theme_contrast_test.dart`** — added the `secondary / surface` pair (the
    follicular arc color; `outline`/`primary`/`tertiary` were already checked).
  - **Tests:** `core/test/cycle/cycle_phase_test.dart` (17 — no cycle/prediction, gap cycle,
    pregnancy gap, future-dated period, degenerate fertile window, each phase incl. boundary
    days, overdue-stays-luteal, ongoing-period-runs-through-today, zero-length-follicular,
    segment-order); `app/test/cycle/cycle_wheel_test.dart` (10 — each phase renders, placeholder
    never fabricates a phase, tap reaches the quick-log callback from both the active and
    placeholder states, `reduceSpokenDetail` on/off, dark mode). Full a11y sweep (guideline,
    semantics-label, contrast incl. the new pair, keyboard-nav, text-scaling to 2.0×, both new
    surfaces) green — no new skips.
  - **Constraints honoured:** no new dependency (Dart or platform); no schema change; `core`
    stays Flutter-free / `DateTime.now()`-free.
**Phase 1 exit gate:** a new user can log periods/symptoms/BBT/meds, gets correctable range
predictions, can lock the app, can back up and restore, and can log a loss/birth — all offline,
free, in dark mode, with inclusive copy. Retention + a working correction loop are the product
threshold (`requirements.md` Recommendations, Stage 1).

**Exit-gate status — MET (2026-08-30).** All eleven slices p1.1–p1.11 merged to `main`
(PRs #9, #10, #12–#20) with CI green; each slice's acceptance criteria were verified in its PR. The app now covers: period start/end + calendar/history, flow/spotting/clots,
derived cycles + variability, correctable range predictions with an explicit late-period state,
symptoms/mood/discharge + custom symptoms, manual BBT + cervical-mucus, medication/BC + one
reminder, anonymous-by-default + optional PIN + first-run privacy explainer, neutral theme with
dark mode + inclusive copy, encrypted backup/restore, and pregnancy-loss/birth/postpartum
events that break the cycle chain — all on-device and free. Outstanding non-blockers carried
forward: the p0.5 manual physical-device smoke table, and the per-slice §9 follow-ups.

*(p1.12 — cycle phase wheel — added later as a Phase 1 core-tracking-UX sibling, user-requested
2026-09-05; not a gate item.)*

---
