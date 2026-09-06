### Phase 4 — Notifications & reminders

**Requirement refs:** §7, §8 (notification a11y / verbosity control), §9(6), §9(7).

**Phase-wide constraints:** no new runtime dependency (the p1.7 notification stack — `flutter_local_notifications` + `flutter_timezone` + `timezone` — covers all of Phase 4); no schema change (new `ReminderKind` values are additive text in `reminders.kind`; app-wide prefs use the `app_settings` KV store); notifications stay **inexact** — no exact-alarm permission, manifest untouched; no new CI workflow.

#### p4.1 — Per-category notification channels, each independently toggleable
- **PR:** [#45](https://github.com/Abbo0dio/olf/pull/45) · squash `ef50695`
- **Branch / worktree:** `feat/p4.1-notification-categories` / `../olf-wt/p4.1` (removed)
- **Owner:** worker: phase4
- **Depends on:** p1.7 (reminder stack + seams), p3.6 (`predictorProvider` for event-relative categories)
- **Requirement refs:** §7 (granular category controls — the #1 notification complaint), §9(6)
- **Goal:** Replace p1.7's single `ReminderKind.medication` daily reminder with the full set of independently-controllable reminder categories, each with its own OS channel, its own stored on/off + timing, and its own row in a Settings → Notifications section. Turning one category on or off never touches another.
- **Categories (this slice):** `upcomingPeriod`, `fertileWindow`, `medication`, `bbtPrompt`, `latePeriodCheckIn`. Content reminder types are **not** created here (no such subsystem exists).
- **Acceptance criteria:**
  - `core`: `ReminderKind` gains `upcomingPeriod`, `fertileWindow`, `bbtPrompt`, `latePeriodCheckIn` (keep `medication`). **No `Reminders` table change, no migration** — values store as text in the existing `kind` column.
  - `core`: new pure module (`reminder_planning.dart` or your naming) exposing `DateTime? nextFireTime({required ReminderKind kind, required ReminderSchedule schedule, required CyclePrediction? prediction, required DateTime today})`. Rules:
    - `medication` / `bbtPrompt` → next daily occurrence via the existing `nextOccurrence(schedule, from: today)` (don't duplicate the roll-to-tomorrow logic).
    - `upcomingPeriod` → `prediction.nextPeriodExpected` minus `kUpcomingPeriodLeadDays` (2), at the schedule's `hour:minute`; `null` if `prediction == null` or that instant is already before `today`.
    - `fertileWindow` → `prediction.fertileWindow.start` at the schedule's time; `null` if no prediction / already past.
    - `latePeriodCheckIn` → `prediction.nextPeriodExpected` plus `kLateCheckInGraceDays` (2) at the schedule's time; `null` unless `today` is already at/after that instant (only nudge once actually late).
    - All thresholds named consts; `today` injected; no `DateTime.now()`; no Flutter import.
  - `app`: `ReminderScheduler` seam generalises — keep `scheduleDaily` for the fixed-time daily kinds; add a way to schedule an event-relative one-shot at a computed instant (shape is yours; `scheduleAt(ReminderKind kind, DateTime when)` with a plain `zonedSchedule` and no `matchDateTimeComponents` is a fine default). `cancel(kind)` / `ensurePermission()` unchanged.
  - `app`: **one Android channel per kind** (`olf_reminder_<kindName>`, distinct human name + description each, all `visibility: private`, `defaultImportance`); **one stable notification id per kind** (extend `_idFor` with a distinct constant per kind — no collisions with p1.7's 1001).
  - `app`: per-kind generic body text via a lookup (`notificationCopyFor(kind)`), fixed and lock-screen-safe — no medication/method/diagnosis words, passes the p1.9 inclusive-language lint and a no-PHI check. (Full copy audit is p4.3; safe placeholders are enough here.)
  - `app`: `ReminderController` drops the hard-coded `ReminderKind.medication`; `setEnabled(kind, enabled:)` / `setTime(kind, hour:, minute:)` for any kind. Enable → permission, write row, schedule via the planning module (daily vs one-shot). Disable → write row, cancel that kind only.
  - `app`: a `reminderSyncProvider` (your shape) that watches `cyclesProvider` / `predictionProvider` and re-plans the event-relative categories (`upcomingPeriod` / `fertileWindow` / `latePeriodCheckIn`) whenever the forecast moves — logging a period reschedules the next-period nudge with no user action. Fixed-time kinds untouched. Also re-plan on app resume / start-up.
  - `app`: Settings gains a **Notifications** section — one `SwitchListTile` + time control per category, each reading/writing only its own row, with an honest one-line sub-label ("About 2 days before your predicted start"; "Around when your fertile window is estimated to begin"; "Every day at a time you choose"; "If your period hasn't been logged 2 days after it was expected"). Dark mode + gender-neutral copy.
  - p1.7's medication reminder keeps working with its existing stored row untouched. The standalone meds-page reminder UI stays in place and functional this slice (both it and the new Settings row drive the same `medication` row) — it's removed in **p4.6**.
  - No new dependency; no schema change; manifest untouched; `core` Flutter-free; no `DateTime.now()` in `core`.
- **Tests required:**
  - `core/test/reminders/reminder_planning_test.dart` — every kind's `nextFireTime`: daily kinds roll to tomorrow; `upcomingPeriod` lands lead-days early at the chosen time; `fertileWindow` anchors on window start; `latePeriodCheckIn` is `null` until overdue then fires; every event-relative kind is `null` when `prediction == null`; pure wall-clock maths (DST-agnostic, mirrors `nextOccurrence`).
  - `app/test/reminders/reminder_controller_test.dart` — extended: enabling each kind schedules exactly that kind (fake scheduler records `(kind, when)`); disabling cancels exactly that kind; no cross-talk.
  - `app/test/reminders/notification_settings_test.dart` — five independent switches; toggling one leaves the others' stored rows unchanged; a category with no prediction shows its row with an "available once there's enough history" affordance, not a broken time.
  - `app/test/reminders/reminder_sync_test.dart` — adding/editing a period re-plans `upcomingPeriod` (fake scheduler sees a new one-shot at the shifted instant) and does NOT reschedule `medication`.
  - Full `core` + `app` suites + analyze + format + dependency-audit stay green.
- **Notes / detail:**
  - One-shot reminders must be re-armed after firing (no OS "repeat every cycle"). The sync-provider re-plan on prediction change + a start-up/resume pass are the re-arm paths. A fired-but-not-yet-re-armed reminder is acceptable degradation for this slice — log any gap.
  - Behaviour-timed delivery (learned logging hour) is **p4.2** — here event-relative categories fire at the user's chosen time, default 09:00.
  - Quiet-hours suppression is **p4.4** — none in this slice.
  - **As built (worker: phase4):**
    - `core`: `ReminderKind` expanded (additive `EnumNameConverter`, `.g.dart` byte-identical — verified with `build_runner`, no migration). New `core/lib/src/reminders/reminder_planning.dart` — `nextFireTime(...)` + `isEventRelativeReminder` + `eventRelativeReminderKinds` + named consts `kUpcomingPeriodLeadDays`/`kLateCheckInGraceDays`; pure, `DateTime`-injected, uses `nextOccurrence` for the daily kinds. Exported from `olf_core.dart`.
    - `app`: `ReminderScheduler` gains `scheduleAt(kind, when)` (one-shot, no `matchDateTimeComponents`, past instant → `now + 1min`). `local_notification_reminder_scheduler.dart` — `_channelFor(kind)` (one `olf_reminder_<name>` channel each, `private`/default), `_idFor` 1001–1005, `_detailsFor`, `notificationCopyFor` bodies; `ensureInitialized()` also deletes p1.7's orphaned `olf_daily_reminder` channel on upgraded installs. New `reminder_copy.dart` — per-kind notification bodies (medication body kept verbatim = p1.7's) + Settings titles/sub-labels + `reminderCategoryOrder`.
    - `app`: `ReminderController` is now kind-generic and takes `prediction: () => ...` + `now`; `_apply` sends fixed kinds to `scheduleDaily` and event-relative kinds to `scheduleAt` (or `cancel` when `nextFireTime` is `null`). `reminder_providers.dart` — `reminderScheduleProvider` (`.family` per kind), `reminderControllerProvider` wired to `predictionProvider`, `medicationReminderProvider` kept for the p1.7 meds page (folded in p4.6), and `reminderSyncProvider` → a `ReminderSync` that `ref.listen`s `predictionProvider` (`fireImmediately`) and re-arms the three event-relative kinds. `HomePage` watches `reminderSyncProvider` (same fire-and-forget pattern as the p2.3 retention sweep) — that is the start-up + forecast-change re-plan path.
    - `app`: new `notifications_page.dart` — `Settings → Notifications` (a `_SectionHeader('Notifications')` + one `ListTile` opening `NotificationsPage`). The page renders `reminderCategoryOrder`: a `SwitchListTile` per kind (own row only) + a `Time` `ListTile` when enabled; an event-relative kind with no forecast shows *"Available once there's enough logged history to predict."* instead of a time. `meds_page.dart` `_ReminderSection` updated to the new controller signature and still drives the same `medication` row.
    - **Gap logged (§9 — p4.1 follow-ups (a)):** a dedicated `AppLifecycleState.resumed` re-plan was **not** added — start-up (`fireImmediately`) + every forecast change are covered via the `HomePage`-watched `reminderSyncProvider`; a resume with no data change relies on the next `HomePage` rebuild. A `resumed` re-arm hook in `AppGate` is a small p4.x follow-up. Per the dispatch, a fired-but-not-yet-re-armed reminder is acceptable degradation for this slice.
    - **Interpretation note:** the "Settings → Notifications **section**" is one nav row opening a dedicated `NotificationsPage` holding the five category controls — consistent with the Pregnancy / Accuracy / Backup rows, and keeps the main settings list scannable. The five switches themselves are the section.
  - **Files:** `core/lib/src/db/tables.dart` (enum + docs), `core/lib/src/reminders/reminder_planning.dart` (new), `core/lib/olf_core.dart` (export), `core/test/reminders/reminder_planning_test.dart` (new); `app/lib/src/reminders/{reminder_scheduler,local_notification_reminder_scheduler,reminder_controller,reminder_providers,meds/meds_page}.dart`, `app/lib/src/reminders/{reminder_copy,notifications_page}.dart` (new), `app/lib/src/settings/settings_page.dart` (+ Notifications section), `app/lib/src/home_page.dart` (+ `reminderSyncProvider` watch); `app/test/support/fake_reminder_scheduler.dart` (+ `scheduleAt` / `oneShotFor`), `app/test/reminders/{reminder_controller_test,notification_settings_test,reminder_sync_test}.dart`.

#### p4.2 — Behaviour-timed delivery
- **PR:** [#46](https://github.com/Abbo0dio/olf/pull/46) · squash `19c2258`
- **Branch / worktree:** `feat/p4.2-behaviour-timed` / `../olf-wt/p4.2` (removed)
- **Owner:** worker: phase4 · **Depends on:** p4.1
- **Requirement refs:** §7 (behavior-timed reminders — send when the user typically logs)
- **Goal:** The three cycle-event categories (`upcomingPeriod`, `fertileWindow`, `latePeriodCheckIn`) fire at the hour the user actually tends to log, learned on-device, with a clean fallback to the chosen/09:00 time when history is thin. `medication` and `bbtPrompt` stay fixed-time (clock-anchored by nature).
- **Acceptance criteria:**
  - `core`: pure `learnPreferredHour({required List<DateTime> logTimestamps, required DateTime now, int recentWindow = 30, int minSamples = 8}) → int?` — representative hour (median / circular-mode) of the most recent `recentWindow` logging events, or `null` below `minSamples`. Deterministic, no `DateTime.now()`, named consts.
  - `core`: a `LoggingActivityRepository` seam + drift impl returning recent `createdAt` across the user-logging tables (`periods`, `daily_flows`, `daily_symptom_entries`, `bbt_entries`, `cervical_mucus_entries`) — read-only, existing columns, no schema change.
  - `app`: planning-module callers pass the learned hour for the three cycle-event kinds; `null` → stored/09:00. The hour is recomputed, never stored.
  - Add one line to `docs/threat-model.md`: the usual-logging-hour is derived and used only on-device, never stored or transmitted.
  - No toggle, no schema change, no dependency.
- **Tests required:** `learnPreferredHour` units (empty / thin / clear-mode / bimodal / all-same-hour / midnight wrap); a `LoggingActivityRepository` drift test; a planning test that an established logging hour overrides the default for `upcomingPeriod` but not `medication`; threat-model guard test passes.
- **Build detail (worker: phase4):**
  - **`core/lib/src/reminders/preferred_hour.dart`** (new) — `int? learnPreferredHour({required List<DateTime> logTimestamps, required DateTime now, int recentWindow = kPreferredHourRecentWindow, int minSamples = kPreferredHourMinSamples})`.
    - Filter `logTimestamps` to those within `recentWindow` days of `now` (`!ts.isBefore(now.subtract(Duration(days: recentWindow)))`); `now` injected, no `DateTime.now()`.
    - `< minSamples` after filtering → `null`.
    - Otherwise return the **circular mean hour** of the samples (each `ts.hour` as an angle `2π·h/24`, average the unit vectors, convert back, round to `0..23`, `24 → 0`). Circular so 23:00 + 01:00 average to midnight, not noon. Deterministic; ties broken toward the lower hour via a fixed epsilon nudge documented in code.
    - Named consts `kPreferredHourRecentWindow = 30`, `kPreferredHourMinSamples = 8`. Exported from `olf_core.dart`. Pure Dart, no Flutter, no `DateTime.now()`.
  - **`core/lib/src/reminders/logging_activity_repository.dart`** (new) — `abstract interface class LoggingActivityRepository { Future<List<DateTime>> recentLogTimestamps({required DateTime since, int limit = kPreferredHourQueryLimit}); }` (`kPreferredHourQueryLimit = 200`, generous headroom over `recentWindow`).
  - **`core/lib/src/reminders/drift_logging_activity_repository.dart`** (new) — reads `createdAt` (all five tables already have it: `Periods`, `DailyFlows`, `DailySymptomEntries`, `BbtEntries`, `CervicalMucusEntries`) with `createdAt >= since`, `UNION ALL` via five typed `selectOnly` queries (or five `select().get()` merged in Dart — whichever keeps it simple and Flutter-free), sorted desc, capped at `limit`. **Read-only, existing columns, no schema change, no migration.**
  - **`core`: `nextFireTime` seam** — add an optional `int? overrideHour` param to `nextFireTime` (defaults `null`). When non-null and `kind` is event-relative, the computed instant uses `overrideHour:00` instead of `schedule.hour:minute`. Keeps `nextFireTime` pure (no repo, no learning inside it); the caller decides the hour. Fixed kinds ignore `overrideHour`.
  - **`app`: `loggingActivityRepositoryProvider`** — `Provider<LoggingActivityRepository>` over `appDatabaseProvider.requireValue` (same gated pattern as `reminderRepositoryProvider`).
  - **`app`: `preferredHourProvider`** — `FutureProvider<int?>` (autoDispose): reads `loggingActivityRepositoryProvider.recentLogTimestamps(since: now − 30d)`, returns `learnPreferredHour(logTimestamps: …, now: DateTime.now())`. Recomputed on demand, **never written to `app_settings` or anywhere else**.
  - **`app`: two call sites** pass the learned hour to `nextFireTime` for event-relative kinds only:
    - `ReminderController._apply` — take `preferredHour` from a new `int? Function() preferredHour` ctor param (mirrors the existing `prediction` / `now` injection); default `() => null`. `reminderControllerProvider` wires `() => ref.read(preferredHourProvider).value`.
    - `ReminderSync.replan` — read `ref.read(preferredHourProvider).value` (or accept it as a `replan([prediction, preferredHour])` arg for the fireImmediately path) and pass to `nextFireTime`.
  - Fallback chain: learned hour → else the category's stored `schedule.hour:minute` → else `ReminderController.defaultHour` (09:00). `minSamples` not met or no history ⇒ learned hour is `null` ⇒ stored time, exactly as p4.1.
  - **`app`: `notifications_page.dart` stays honest** (review follow-up) — for the three event-relative kinds, when the learned hour is present the row shows a **read-only** "Around _h:mm_" line + "Timed to when you usually log" (no picker, since the learned hour wins regardless); when it is `null` the manual picker stays, captioned "Until you've logged enough, we'll send these around this time." `medication` / `bbtPrompt` keep the plain picker.
  - **`docs/threat-model.md`** — append one sentence to the existing **Phase 4 opening gate** Review-log entry (resolving its own watch item): the usual-logging-hour is computed in memory from `createdAt` timestamps already in the encrypted DB, used only to pick a notification time on-device, and is never stored or transmitted.
- **Edge cases:**
  - Empty list, all-same-hour (circular mean = that hour), two tight clusters (bimodal — circular mean lands between; acceptable, it is still "when they tend to log"), samples spanning midnight (23/0/1 → ~0, not ~12), exactly `minSamples`, `recentWindow` boundary (a timestamp exactly `recentWindow` days old is included).
  - DST: `learnPreferredHour` works on wall-clock `.hour` only — no timezone maths, matches `nextFireTime` / `nextOccurrence`.
  - `preferredHourProvider` in the DB-error / decoy branch: `loggingActivityRepositoryProvider` is gated on `appDatabaseProvider` `AsyncData` like every other repo; the FutureProvider just yields `null` → stored time.
- **Test plan:**
  - `core/test/reminders/preferred_hour_test.dart` — empty → null; 7 samples → null (below `minSamples`); 8+ tightly at 21:00 → 21; clear single mode with noise → that hour; bimodal 8:00/20:00 → 14 (documented midpoint); all identical → that hour; samples at 23:00/00:00/01:00 → 0 (midnight-wrap); a sample exactly 30 days old is counted, 31 days is not; `now` injected, asserted no `DateTime.now()` by the no-`DateTime.now()` core guard already in CI.
  - `core/test/reminders/drift_logging_activity_repository_test.dart` — seed rows across all five tables with mixed `createdAt`; assert the merged list is every row `>= since`, newest first, capped at `limit`; a table with no rows contributes nothing; `since` in the future → empty.
  - `core/test/reminders/reminder_planning_test.dart` (extend) — `nextFireTime(..., overrideHour: 7)` puts an `upcomingPeriod` fire at 07:00 not the schedule's time; `overrideHour` ignored for `medication` / `bbtPrompt`; `overrideHour: null` == p4.1 behaviour.
  - `app/test/reminders/reminder_controller_test.dart` (extend) — with a fake preferred hour of 6, enabling `upcomingPeriod` arms a one-shot at 06:00; enabling `medication` still uses its stored/09:00; preferred hour `null` ⇒ stored time.
  - `app/test/reminders/preferred_hour_provider_test.dart` — repo returns 10 timestamps clustered at 20:00 ⇒ provider yields 20; returns 3 ⇒ yields `null`; DB-error branch ⇒ `null`.
  - `app/test/reminders/reminder_sync_test.dart` (extend) — an established logging hour re-plans `upcomingPeriod` at that hour; `medication` never touched.
  - `docs` guard: `core/test/threat_model_doc_test.dart` still green (Phase 4 entry now has the extra sentence).
  - Full `core` + `app` suites + `analyze --fatal-infos` + `format` + `dependency-audit` + `build_runner` (no `.g.dart` drift) green.
- **Notes / risks:**
  - `learnPreferredHour` is deliberately **independent of the p1.3 regularity heuristics** (different "recent window" meaning — logging cadence, not cycle spread). If a shared notion ever emerges, note it in §9; do not unify here.
  - No `app_settings` key, no toggle, no schema change, no new dependency. If the drift `UNION ALL` turns out to need a raw `customSelect` that reads awkwardly, prefer five typed queries merged in Dart — clarity over one query.

#### p4.3 — Sensitive notification copy
- **PR:** [#47](https://github.com/Abbo0dio/olf/pull/47) · squash `d18dff2`
- **Branch / worktree:** `feat/p4.3-notification-copy` / `../olf-wt/p4.3` (removed)
- **Owner:** worker: phase4 · **Depends on:** p4.1
- **Requirement refs:** §7 (no PHI in notification text; late-period check-in worded sensitively — avoid the "teacher collecting homework" pattern), §9(6), §9(7)
- **Goal:** Every notification string is deliberately written, reviewed, and locked behind a content test: non-alarming, non-clinical, gender-neutral, nothing that reads as surveillance or a demand, nothing that exposes health state on a lock screen.
- **Acceptance criteria:**
  - All notification titles/bodies consolidated in one `notification_copy.dart` (app layer) as named `const`s — mirrors the p1.9 named-constant-copy + content-test pattern.
  - `latePeriodCheckIn` body is invitational, not interrogative ("When you're ready, you can update your dates" — not "Has your period started? Log it now.").
  - No body contains: a medication/method name (keep as a test anyway), a diagnosis word, "pregnan*", an imperative scold, a gendered second-person term, or exclamation-mark urgency.
  - `notification_copy_test.dart` — every `ReminderKind` has a non-empty title + body; denylist; lock-screen-reasonable length; the p1.9 `inclusive_language_test` picks up the new consts automatically.
  - PR description reviews each category's copy against §7's examples.
- **Tests required:** the content test; inclusive-language lint; final strings snapshotted in the plan log.
- **Notes:** strings only, no behaviour change. Any string needing pronouns uses the p1.9 `formsFor` seam, not a literal.
- **Build detail (worker: phase4):**
  - **`app/lib/src/reminders/notification_copy.dart`** (new) — the single home for every string that can reach an OS notification: `const String notificationTitle = 'olf'` (same for every kind — a per-kind title would itself expose health state on a lock screen) + five per-kind body `const`s + `({String title, String body}) notificationCopyFor(ReminderKind)`. Doc comment states the lock-screen rules the content test enforces.
  - **`app/lib/src/reminders/reminder_copy.dart`** — reduced to the **Settings-facing** labels only (`reminderCategoryTitle` / `reminderCategorySubtitle` / `reminderCategoryOrder`), shown only inside the unlocked app. The notification strings and `notificationCopyFor` moved to `notification_copy.dart`; dropped the `reminder_scheduler.dart` import.
  - **`app/lib/src/reminders/reminder_scheduler.dart`** — removed the p1.7 `reminderNotificationTitle` / `reminderNotificationBody` consts (now in `notification_copy.dart`); the interface is unchanged.
  - **`app/lib/src/reminders/local_notification_reminder_scheduler.dart`** — import swapped `reminder_copy.dart` → `notification_copy.dart` (only user of `notificationCopyFor`); no behaviour change.
  - **Final copy** (title is `olf` for all five):
    - `medication` — `Time for your daily check-in.` (byte-identical to p1.7; the medication path is unchanged).
    - `bbtPrompt` — `A gentle nudge for your morning note.`
    - `upcomingPeriod` — `A quick heads-up for the days ahead.`
    - `fertileWindow` — `A gentle check-in — open olf whenever you have a moment.`
    - `latePeriodCheckIn` — `When you're ready, you can open olf to update your dates.` (invitational, not interrogative — no "has your period started?", no "log it now").
  - **`app/test/reminders/notification_copy_test.dart`** (new) — every `ReminderKind` has a non-empty title + body; title is always the bare app name; medication body byte-identical to p1.7; denylists for medication/method/device names, cycle-phase / symptom / health-state words, diagnosis words + "pregnan…", imperative-scold / urgency patterns, `?` / `!`, gendered second-person terms; every body ≤ 90 chars; the late check-in body invites ("when you…") and never interrogates.
  - **`app/test/reminders/reminder_controller_test.dart`** — dropped the p2.4 lock-in test (moved to `notification_copy_test.dart`) and its now-unused `reminder_copy.dart` import.
  - No schema change, no dependency, no behaviour change; the p1.9 `inclusive_language_test` picks up `notification_copy.dart` automatically (it scans all of `lib`).

#### p4.4 — Quiet hours / do-not-disturb window
- **PR:** [#48](https://github.com/Abbo0dio/olf/pull/48) · squash `4f612b3`
- **Branch / worktree:** `feat/p4.4-quiet-hours` / `../olf-wt/p4.4` (removed)
- **Owner:** worker: phase4 · **Depends on:** p4.1
- **Requirement refs:** §7, §8
- **Goal:** A single app-wide quiet window (default off) during which no olf notification is delivered; anything that would fire inside the window is shifted to the window's end (not dropped).
- **Acceptance criteria:**
  - `core`: pure `quiet_hours.dart` — `QuietHours({int startHour, startMinute, endHour, endMinute, bool enabled})` + `DateTime applyQuietHours(DateTime candidate, QuietHours q)`: `candidate` unchanged when disabled or outside the window, else the next instant at window end. Handles wrap past midnight (22:00 → 07:00). Deterministic.
  - Storage: one `app_settings` KV key (`SettingKeys.quietHours`, encoded string). No schema change.
  - `app`: `QuietHoursRepository` over the KV store; a Settings → Notifications row (enable + start/end pickers); every scheduling path runs its computed instant through `applyQuietHours` before the OS hand-off.
  - A daily kind whose only slot is inside the window fires at window end that day.
- **Tests required:** `core/test/reminders/quiet_hours_test.dart` — disabled passthrough; before/inside/at both boundaries/after; midnight-wrap; candidate exactly at end. `app` — Settings widget test; controller test that 23:30 with a 22:00–07:00 window reschedules to 07:00.
- **Notes:** apply p4.2's learned hour first, then quiet hours.
- **Build detail (worker: phase4):**
  - **`core/lib/src/reminders/quiet_hours.dart`** (new) — `class QuietHours({int startHour, startMinute, endHour, endMinute, bool enabled})` value (`copyWith` / `==` / `hashCode` / `toString`, matching `ReminderSchedule`) + `const kDefaultQuietHours` (22:00–07:00, **disabled**) + `DateTime applyQuietHours(DateTime candidate, QuietHours q)`. Pure, wall-clock only, no `DateTime.now()`. Half-open window (candidate exactly at start = inside, exactly at end = outside); `end <= start` wraps past midnight — a pre-midnight candidate shifts to the window end on the **next** day, a post-midnight one to the **same** day; `start == end` (zero-width) and `!enabled` are pass-throughs. Result has seconds/millis zeroed. Exported from `olf_core.dart`.
  - **`core/lib/src/settings/settings_repository.dart`** — added `SettingKeys.quietHours = 'quiet_hours'`. KV store only; **no schema change** (the `app_settings` table already exists).
  - **`app/lib/src/reminders/quiet_hours_providers.dart`** (new) — `encodeQuietHours` / `decodeQuietHours` (format `enabled;startH:startM;endH:endM`; any malformed/absent value → `kDefaultQuietHours`, so a bad string never bricks reminders); `quietHoursProvider` (`StreamProvider<QuietHours>` — `kDefaultQuietHours` until the DB gate opens, then `settingsRepository.watch(SettingKeys.quietHours).map(decodeQuietHours)`); `quietHoursControllerProvider` + `QuietHoursController.save(QuietHours)`.
  - **`app/lib/src/reminders/reminder_controller.dart`** — new ctor seam `Future<QuietHours> Function() quietHours` (default `() async => kDefaultQuietHours`). In `_apply`, applied **after** p4.2's learned hour: the event-relative branch wraps `nextFireTime`'s instant in `applyQuietHours` before `scheduleAt`; the fixed-time branch builds today's `hour:minute` slot, runs it through `applyQuietHours`, and — only if it moved — hands `scheduleDaily` a `schedule.copyWith(hour:, minute:)` at the window end (a daily reminder then lands at window-end every day; the stored preference is untouched). A slot outside the window is a no-op.
  - **`app/lib/src/reminders/reminder_providers.dart`** — `reminderControllerProvider` wires `quietHours: () => ref.read(quietHoursProvider.future)`; `ReminderSync.replan` reads `quietHoursProvider.future` once per pass and wraps each event-relative instant in `applyQuietHours`.
  - **`app/lib/src/reminders/notifications_page.dart`** — a `_QuietHoursSection` at the foot of Settings → Notifications: an enable switch (default off) and, when on, Start / End `showTimePicker` rows. Writes go through `QuietHoursController`.
  - **Tests:** `core/test/reminders/quiet_hours_test.dart` (disabled/zero-width pass-through; non-wrap 13:00–14:00 before/at-start/inside/at-end/after; midnight-wrap 22:00–07:00 at 22:00/23:30/03:00/06:59/07:00/12:00 + a month-boundary shift; value semantics). `app/test/reminders/quiet_hours_providers_test.dart` (encode/decode round-trip both ends + malformed→default; `QuietHoursController` persistence). `reminder_controller_test.dart` +group (event-relative inside→window end, outside→untouched; daily inside→window end with the stored time kept, daily outside→kept; disabled window→no shift). `reminder_sync_test.dart` +1 (start-up re-plan pushes a 23:00 learned-hour instant to 07:00). `notification_settings_test.dart` +group (off by default; enabling persists + reveals both ends; a row opens a real picker wired to the store) and the switch-count assertion bumped by one.
  - No new dependency, no schema change, no CI change; notifications stay inexact.

#### p4.5 — Permanent "stop asking me to subscribe" control
  Shipped in v1.0.0, then withdrawn when olf committed to being free forever (2026-09-02):
  the control implied a paywall that will never exist. Build detail and log below are kept
  as-is, under this banner, for history.
- **PR:** [#49](https://github.com/Abbo0dio/olf/pull/49) · squash `d0501f2`
- **Branch / worktree:** `feat/p4.5-subscription-prompt-control` / `../olf-wt/p4.5` (removed)
- **Owner:** worker: phase4 · **Depends on:** —
- **Requirement refs:** §7 ("easy stop asking me to subscribe" control), §9(4)
- **Goal:** Establish now, as an enforceable principle, a single persistent switch that permanently silences subscription/upsell prompting, so Phase 10's paid tier already has a suppression path to honour. No upsell UI exists yet.
- **Acceptance criteria:**
  - `core`: `SettingKeys.suppressSubscriptionPrompts` KV key (absent/`'false'` = allowed; `'true'` = permanently suppressed). A tiny helper/provider `bool get subscriptionPromptsAllowed`.
  - `app`: a Settings row "Don't show subscription offers". On → stays on, no re-prompt / "are you sure you'll miss out" pattern; off again is one tap.
  - A contract note in `docs/` (or a prominent doc-comment) that ALL future upsell paths (Phase 10) MUST check `subscriptionPromptsAllowed` and no-op when false — with a test locking default + suppression.
  - No schema change, no dependency.
- **Tests required:** KV round-trip; `subscription_prompt_policy_test.dart` (default allows; set → suppressed; survives reload); Settings widget test (toggle both ways, no confirmation dialog).
- **Notes:** principle-only now; add a Phase 10 backlog line pointing back here.
- **Build detail (worker: phase4):**
  - **`core/lib/src/settings/settings_repository.dart`** — added `SettingKeys.suppressSubscriptionPrompts = 'suppress_subscription_prompts'` (KV store; **no schema change**) + a pure top-level helper `bool subscriptionPromptsAllowed(String? rawSetting) => rawSetting != 'true'`. Only the exact string `'true'` suppresses; absent / `'false'` / any malformed value ⇒ allowed (fails toward the user's likely intent, matching "absent = allowed"). Already re-exported via `olf_core.dart` — no barrel change.
  - **`app/lib/src/monetization/subscription_prompt_providers.dart`** (new) — `subscriptionPromptsAllowedProvider` (`StreamProvider<bool>`, default `true`; `true` until the DB gate opens, then `settingsRepository.watch(SettingKeys.suppressSubscriptionPrompts).map(subscriptionPromptsAllowed)`) + `setSubscriptionPromptsSuppressed(ref, suppressed:)` writing `'true'` / `'false'`. Mirrors the p2.5 `privacy_providers.dart` opt-in pattern.
  - **`app/lib/src/settings/settings_page.dart`** — a standalone **Subscriptions** section with one `SwitchListTile` **"Don't show subscription offers"**. `value` = suppressed; `onChanged` writes immediately with **no confirmation dialog, no FOMO copy, no re-prompt**. Turning it back off is one tap.
  - **`docs/monetization-principles.md`** (new) — the contract: every subscription / upsell / paid-tier prompt added in Phase 10+ MUST check `subscriptionPromptsAllowedProvider` (or the `subscriptionPromptsAllowed` core helper) and render nothing when it is `false`. A hard gate, not a "show it less often". Free core features are never gated by this — it only ever hides *offers*.
  - **§9 backlog** — added a Phase 10 line pointing back to this control as the gate Phase 10 must honour.
  - **Tests:** `core/test/settings/subscription_prompts_test.dart` (`subscriptionPromptsAllowed`: absent → true, `'false'` → true, `'true'` → false, garbage → true). `app/test/monetization/subscription_prompt_policy_test.dart` (provider default allows; set suppressed → provider reports `false`; a fresh container re-reads `false` from the repo). `app/test/settings/settings_page_test.dart` +1 (toggle the switch both ways → the setting is written and **no** `AlertDialog` appears).
  - No new dependency, no schema change, no CI change, no notification behaviour touched.

#### p4.6 — Fold the p1.7 medication reminder into the unified system
- **PR:** [#50](https://github.com/Abbo0dio/olf/pull/50) · squash `c560f6a`
- **Branch / worktree:** `feat/p4.6-fold-med-reminder` / `../olf-wt/p4.6` (removed)
- **Owner:** worker: phase4 · **Depends on:** p4.1, p4.3, p4.4
- **Requirement refs:** §7, §1.4 (one code path, no dead parallel system)
- **Goal:** Remove the standalone p1.7 medication-reminder UI + bespoke provider so the `medication` category is managed only through the Phase 4 Settings → Notifications section, on the same controller / scheduler / planning path as every other category. No data migration — same row, same `kind`.
- **Acceptance criteria:**
  - `meds_page.dart` loses `_ReminderSection` + its `_SectionHeader('Daily reminder')`; page is now medications + birth control only; doc-comment updated.
  - `medicationReminderProvider` removed (or a thin alias of the generic per-kind provider) — nothing reads a medication-specific reminder provider.
  - `reminder_controller.dart` / `reminder_scheduler.dart` lose lingering `ReminderKind.medication` special-casing and single-reminder assumptions; keep `ReminderController.defaultHour/Minute` as the shared fixed-kind default.
  - An existing enabled `medication` row keeps firing unchanged after the refactor (test).
  - Still-relevant p1.7 `reminder_controller_test.dart` assertions migrate into the unified suites; dead tests deleted.
- **Tests required:** regression test that a pre-existing enabled medication schedule still schedules post-refactor; `meds_page` widget test updated (no reminder section); unified notification-settings test exercises the `medication` row; full suites green.
- **Notes:** pure consolidation, no new capability. If removing `medicationReminderProvider` ripples past the meds page, stop and flag scope.
- **Build detail (worker: phase4):**
  - **`app/lib/src/meds/meds_page.dart`** — removed `_ReminderSection` + its `_SectionHeader('Daily reminder')` + the leading `Divider`; the page is now Birth control + Medications only. Dropped the now-unused `reminder_controller.dart` / `reminder_providers.dart` imports. Doc-comment rewritten (the daily reminder is the `medication` category in Settings → Notifications; the stored row is untouched). **AppBar title `Medications & reminders` → `Medications`** and the `HomePage` icon-button tooltip to match — a consequential rename so the title isn't lying about a control that has moved (ripples: `meds_page_test.dart`, `theme_render_test.dart` finders, one `AndroidManifest.xml` audit comment that named the old screen — comment-only, audit still PASS). **Flag for review:** the dispatch asked only for the doc-comment; the title rename is my call — trivially revertible if unwanted.
  - **`app/lib/src/reminders/reminder_providers.dart`** — **deleted** `medicationReminderProvider` (no alias). Its only reader was `meds_page.dart`; the generic `reminderScheduleProvider(ReminderKind.medication)` (p4.1) already covers the Settings → Notifications surface. **No ripple** outside the meds page + its test.
  - **`app/lib/src/reminders/reminder_controller.dart`** — refreshed the class doc-comment so it no longer frames `medication` as the special p1.7 case (it has been a plain fixed-time kind since p4.1). No behaviour or signature change; `ReminderController.defaultHour` / `defaultMinute` unchanged. `reminder_scheduler.dart` needed no change — its only `medication` mention just names a fixed-time kind.
  - **No data migration, no schema change.** The `reminders` row with `kind = medication` and its OS notification are untouched by this slice.
  - **Tests:** `meds_page_test.dart` — deleted `'turning the reminder on schedules it and persists'` (standalone-path only); added `'no reminder UI here (p4.6)'` (no `SwitchListTile`, no "Daily reminder"; Birth control + Add medication still render); `openMeds` finders updated for the new title. `reminder_controller_test.dart` (fixed-time group) +1 — a row pre-stored enabled (p1.7 shape) written straight to the repo still `scheduleDaily`s at its stored time through the unified controller. `notification_settings_test.dart` +1 — a pre-existing enabled `medication` row surfaces in Settings → Notifications with the switch on and its stored time shown. `theme_render_test.dart` — meds-screen finders updated for the new title.
  - No new dependency, no schema change, no CI change; `medication` notification behaviour unchanged.
**Exit gate:** every notification type separately controllable (p4.1); delivery behaviour-timed with a safe fallback (p4.2); all copy reviewed and locked behind a content test with no PHI (p4.3); a quiet-hours window that shifts rather than drops (p4.4); a permanent "stop asking to subscribe" control, documented as a Phase 10 gate (p4.5) [reverted 2026-09-02, PR #52 — olf is free-forever]; the p1.7 medication reminder on the one unified path (p4.6).

**Exit-gate status — MET (2026-09-02).** All six build slices p4.1–p4.6 merged to
`main` (PRs [#45](https://github.com/Abbo0dio/olf/pull/45)–[#50](https://github.com/Abbo0dio/olf/pull/50))
with CI green; each slice's acceptance criteria were verified in its PR. Each gate
clause maps to the slice that satisfies it:

- **Every notification type separately controllable** → **p4.1** (#45, `ef50695`) —
  one Android channel per `ReminderKind` (`olf_reminder_<kind>`, `visibility: private`)
  and an independent enable switch + time control per category in Settings →
  Notifications; toggling one never touches another.
- **Behaviour-timed delivery with a safe fallback** → **p4.2** (#46, `19c2258`) —
  `learnPreferredHour` derives the user's usual logging hour on-device from
  `createdAt` timestamps already in the encrypted DB (circular mean, `now`
  injected), applied to the three cycle-event kinds; below `minSamples` or with no
  history it returns `null` and delivery falls back to the stored / 09:00 time.
  The hour is recomputed every read, **never stored or transmitted**.
- **Copy reviewed, no PHI** → **p4.3** (#47, `d18dff2`) — every notification
  title/body is a named `const` in `notification_copy.dart`; the title is the bare
  app name `olf` for every kind (a per-kind title would itself leak health state on
  a lock screen); `notification_copy_test.dart` locks a denylist (method/device
  names, cycle-phase / symptom / diagnosis words, `pregnan…`, scold / urgency
  patterns, `?` / `!`, gendered terms) and the p1.9 inclusive-language lint picks
  the file up automatically.
- **Quiet hours that shift rather than drop** → **p4.4** (#48, `4f612b3`) — pure
  `applyQuietHours` moves any fire instant inside the window to the window's end
  (half-open; midnight-wrap safe; seconds zeroed); default **off**; a daily
  fixed-time kind inside the window fires at window-end every day with its stored
  time untouched.
- **"Stop asking to subscribe"** → **p4.5** (#49, `d0501f2`) — a single persistent
  `SettingKeys.suppressSubscriptionPrompts` switch (immediate, no confirmation, no
  re-prompt) plus `docs/monetization-principles.md`: a hard-gate contract that
  every Phase 10+ upsell prompt must check `subscriptionPromptsAllowedProvider`
  (or the `subscriptionPromptsAllowed` core helper) and render nothing when
  suppressed. **[reverted 2026-09-02, PR #52 — olf is free-forever]** — the
  code, docs, and tests for this control were removed when olf committed to having
  no paid tier ever; the clause is left here as history, not a live deliverable.
- **p1.7 medication reminder unified** → **p4.6** (#50, `c560f6a`) — the standalone
  `_ReminderSection` UI and `medicationReminderProvider` are removed; `medication`
  is now a plain fixed-time category on the same `ReminderController` / scheduler /
  planning path as every other kind. Same DB row, same `kind`, no migration.

**Phase 4 shipped with zero new runtime dependencies and zero schema changes** —
the p1.7 notification stack (`flutter_local_notifications` + `flutter_timezone` +
`timezone`) covered the whole phase, new `ReminderKind` values are additive text in
the existing `reminders.kind` column, and every app-wide preference (learned hour,
quiet-hours window) is either recomputed in memory
or an opaque string in the existing `app_settings` KV store. Notifications remain
**inexact by design** (`AndroidScheduleMode.inexactAllowWhileIdle`, no exact-alarm
permission, manifest untouched) — a nudge does not need to hit the minute; an
exact-alarm path is backlog (§9), not a gate.

---
