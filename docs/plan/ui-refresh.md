# UI / UX refresh — refinement pass (2026-09-08)

Not a numbered roadmap phase. The feature roadmap (phases 9–13) stays **paused**
(`decisions.md` 2026-09-07). This is refinement of the **current** scope — the
information architecture, the logging flow, and visual consistency of what
already ships (phases 0–8) — run as dispatched slices through the normal
worktree → PR → gate → merge flow because it touches core tested surfaces
(`screen_nav` inventory, the a11y sweeps, `perf/log_period_tap_budget_test.dart`,
`a11y/theme_contrast_test.dart`).

Origin: the 2026-09-08 IA review (session `8e012caa`). Verdict — the visual
language is fine; the structure isn't. Three problems: one unbounded home scroll,
two overlapping day-log sheets, and a 933-line Settings page doing duty as the
app menu.

**Invariants for every slice below** (same as `conventions.md` plus):

- No new runtime dependency, no new permission, no schema change, no new egress,
  no CI-workflow change. Any of those → STOP and negotiate (§5).
- `perf/log_period_tap_budget_test.dart`: `maxTaps = 2` and the feedback budget
  are **inviolable**. The canonical fast path may be *re-pointed* to a new widget
  as long as home → logged period stays ≤ 2 taps and the ack stays inside the
  window. If a change can't hold ≤ 2 taps, STOP and negotiate.
- `core` stays Flutter-free / `DateTime.now()`-free — but these slices are all
  `app/`-only; no `core` change is expected.
- Every new or moved top-level surface is added to `app/test/support/screen_nav.dart`
  and the a11y + text-scaling sweeps kept green (this is DoD, not negotiation).
- WCAG 2.2 AA holds: nothing colour-only, 44px targets, text scales to 2.0×,
  `reduceSpokenDetail` redaction preserved on every sensitive read-out, motion
  gated on the reduce-motion path.
- Discreet/neutral/non-gendered language and look (`requirements.md` §4, §9(7)).

Status is tracked in `.herdsman/state.md` `## Tasks`, not here.

---

## r1 — Consolidate the forecast / banner area into one widget

**Goal.** Replace the loose stack of mutually-exclusive "instead of a forecast"
cards on the home screen with a single `ForecastArea` widget that renders
**exactly one** child.

**Why.** `period_calendar_page.dart` currently renders `_PredictionCard` only
`if (prediction != null && !pregnancyModeOn && !bcRecalActive && !perimenopauseGapSuppress)`,
while `_PregnancyStatusCard`, `_RecalibrationNote` and `_PerimenopausePausedNote`
each appear on their own independent conditions. A user in two modes can get a
pile of banners where the forecast used to be, and the boolean guard is already
fragile.

**Shape.** New `app/lib/src/prediction/forecast_area.dart` (name/location the
Worker's call). Priority order, first match wins:

1. overdue check-in — `prediction.isOverdue`
2. birth-control recalibration note — `bcRecalActive`
3. perimenopause paused note — `perimenopauseGapSuppress`
4. pregnancy mode on — render nothing (the week view is the mode screen)
5. forecast card — default, when `prediction != null`
6. nothing — no prediction yet

When two conditions coincide (e.g. overdue **and** recalibration) the shown card
gets one extra secondary line rather than a second card.

`_CorrectionNotice` stays a **separate** widget rendered directly above
`ForecastArea` — it is transient, time-boxed, `liveRegion` feedback, semantically
different. `_PregnancyStatusCard` (post-loss/birth recovery) also stays separate
and unchanged — recovery state already suppresses predictions, so it never
co-renders with the forecast.

**Acceptance criteria.**

- Home renders at most one forecast-area card in every mode combination.
- Each priority branch shows the right card (widget tests, one per branch + the
  "only one shows" invariant with several modes on at once).
- `_CorrectionNotice` still appears above it after a period edit, unchanged.
- No visible-copy changes to any of the existing notes/cards (text is reused
  verbatim — the copy tests stay green).
- Existing `period_calendar` / home widget tests still green; `screen_nav`
  forecast-related surfaces unchanged (no new surface).

**Tests required.** New `forecast_area_test.dart` (per-branch + invariant);
existing home tests unchanged and green.

**Risk.** Low — pure `app/` refactor, no nav change, no new surface.

**Depends on.** —

---

## r2 — One unified day-log sheet

**Goal.** Merge `showFlowQuickLog` and `showSymptomDaySheet` into a single
date-titled bottom sheet with sections **Flow · Symptoms · Temperature · Fluid**
(+ a slot for active-mode quick inputs — PMDD rating, endo pain — when those
modes are on). Every entry point routes to it.

**Why.** Today there are two sheets and which one opens depends on the entry
point *and* whether the day is already a period day, with buttons to hop between
them. "Log today" is not one predictable action, and temperature/fluid living
under a sheet titled "symptoms" is odd.

**Shape.**

- One `showDayLog(context, date: …)` opening a sheet titled with the date
  (e.g. "Tue 8 Sep"). Sections as collapsible blocks; the most-relevant one is
  expanded on open — Flow for a period day or today, Symptoms otherwise.
- Every choice still upserts immediately — no Save button (keeps the ≤ 2-tap
  path: open sheet → tap intensity = done).
- Route to it from: the cycle-wheel tap, both `_Summary` chips, and every
  calendar-day tap. The old `showFlowQuickLog` / `showSymptomDaySheet` entry
  points collapse into it.
- Keep "Start a period" / "Edit period dates" as actions inside the sheet
  (shown for the right day state), and "Manage symptoms" as it is now.
- Active-mode quick inputs: if PMDD or endo mode is on, their one-tap daily
  input appears as its own section here (re-using the existing rating / pain
  sheet widgets, not a reimplementation).
- Leave the mid-scroll "Add a period" button on the home scroll for now — r3
  replaces it with the FAB.

**Acceptance criteria.**

- One sheet, one title style, reached identically from every entry point.
- `perf/log_period_tap_budget_test.dart` green — re-point its fast path if
  needed, `maxTaps`/budget unchanged.
- The two-tap flow/spotting path from `flow_quick_log_test.dart` still holds
  (re-point as needed).
- Temperature (incl. the p8.1a passive-reading sub-label) and cervical-fluid
  inputs behave exactly as they do in today's symptom sheet.
- `reduceSpokenDetail` redaction preserved on every chip/read-out.
- `screen_nav.dart`: `flow_quick_log` + `symptom_day_sheet` surfaces replaced by
  the unified `day_log` surface (net inventory −1); a11y + text-scaling sweeps
  updated and green; the p8.1a "day sheet with a passive wrist reading" surface
  re-pointed to the new sheet.

**Tests required.** New `day_log_sheet_test.dart` (sections, default expansion,
immediate upsert, every entry point); update `flow_quick_log_test.dart` +
`symptom_day_sheet_test.dart` (or fold them in); perf + a11y sweeps green.

**Risk.** Medium — most-used path, and a HARD perf gate rides on it.

**Depends on.** r1 (merge order only — disjoint files otherwise).

---

## r3a — Bottom navigation shell + Calendar tab

**Goal.** Introduce a 3-destination `NavigationBar` — **Home · Calendar ·
Patterns** — with Settings staying a top-right gear icon (a utility, not a
destination). This slice builds the shell and the **Calendar** tab; the
**Patterns** tab is an empty scaffold wired in r3b.

**Why.** The whole app is one screen + a Settings dump. There is no way to reach
longer-term views except by scrolling the home stack or diving into Settings.

**Shape.**

- `NavigationBar` at the app shell (`home_page.dart` / a new `app_shell.dart`),
  three destinations, neutral labels + `_outlined`/filled icon pairs, no colour
  coding. Selected-tab state is ephemeral (no persistence needed).
- **Home tab** slims to: cycle wheel + caption, `ForecastArea` (r1),
  `_CorrectionNotice`, a single "this cycle" card (fertile window + BBT
  sparkline + observed fertile signs — tap through to Patterns), a horizontal
  **active-mode chip strip** (one chip per enabled mode → that mode's screen;
  absent when no modes), and "Recent activity" = the last 3 logged days (tap →
  day-log sheet) with a "See all in Calendar" link.
- **Calendar tab**: the month grid (add horizontal swipe between months + a
  "jump to today" control alongside the existing chevrons), then the full
  history as a **lazy, year-grouped** list (`ListView.builder`/slivers — today's
  `_History` builds every row in a `Column`). Each row → day-log sheet. An
  overflow menu on this tab holds **Pregnancy loss & birth** and **Medications**
  (both demoted from the home AppBar).
- **"Log" FAB** on Home and Calendar → `showDayLog` for today (Calendar: for the
  selected day). Remove the mid-scroll "Add a period" button.
- **"Mark <date> as period start"** — a **one-tap direct-write** action in the
  day-log sheet's Flow section, shown only when `date` is not already inside a
  logged period. Writes through the **same** `periodRepository.addPeriod` call +
  outcome / correction-notice path the period editor's default Save uses for a
  today-start (verified parity — same `PeriodDraft`, same post-write refresh and
  notice — not a parallel write path); no editor surface. The overdue check-in
  card's "mark as period start", if present, routes through the same helper.
  The period **editor** stays the path for editing an existing period and for
  starting one on an arbitrary past day (the sheet's "Edit period dates" /
  "Start a period" actions, and calendar-cell entry).
  *(§5 negotiation, r3a, 2026-09-08 — resolved option (a): a pure FAB →
  `showDayLog` fast path is 3 taps to a period write via "Start a period" →
  editor → Save, and re-pointing the gate to a flow write would change what it
  asserts. This one-tap action keeps the gate asserting a real period write with
  its existing "Period saved." / "Day 1" ack. Rejected (b) a context-aware FAB —
  reintroduces the "'Log' is not one predictable action" problem r2 fixed — and
  (c) re-pointing the gate to a flow write + a new SnackBar ack — permanently
  weakens the gate.)*
- Month grid + full history are **removed from the Home tab**.

**Acceptance criteria.**

- Three tabs, switchable, each retains scroll position on return.
- `perf/log_period_tap_budget_test.dart` green — fast path re-pointed to: tap the
  "Log" FAB → tap "Mark today as period start" (in the opened day-log sheet's
  Flow section) → assert `Period saved.` + `Day 1`. `maxTaps = 2` and the
  feedback budget **unchanged**; the assertion still verifies a real period
  write. (Resolved §5 negotiation — see the Shape note above.)
- Home no longer shows the month grid or the full history list; "Recent
  activity" shows ≤ 3 days.
- Calendar history list is lazily built and year-grouped.
- Medications and Pregnancy-loss/birth still reachable (Calendar overflow); the
  home AppBar drops the medication action.
- `screen_nav.dart`: new `calendar_tab` surface (+ `home_tab` if materially
  different from today's `period_calendar`); a11y + text-scaling + keyboard-nav
  sweeps extended and green.

**Tests required.** `app_shell_test.dart` (tab switching, FAB target, scroll
retention); updated `period_calendar_test.dart`; perf + a11y sweeps green.

**Risk.** High — biggest diff, changes the nav model and the `screen_nav`
inventory, and the perf gate's fast path moves.

**Depends on.** r1, r2.

---

## r3b — Patterns tab

**Goal.** Fill the Patterns scaffold from r3a with the longer-term views, moved
out of Settings and the home scroll.

**Shape.** Patterns hosts, as sections or a short sub-list:

- Prediction accuracy (`AccuracyPage` content) — moved from Settings → Cycle.
- Cycle stats (the `_CycleStatsCard` content, expanded).
- BBT history — this cycle **and** prior cycles (today the home card is
  this-cycle-only).
- Symptom × cycle-phase correlations (the p7.4 `CorrelationChart`), for users
  with enough data.
- The enabled modes' views — one row per active mode into its screen — and the
  entry to the **Modes on/off** screen (`ModesPage`), moved from Settings →
  Modes.

**Acceptance criteria.**

- Accuracy and the Modes on/off screen are reachable from Patterns; their
  Settings rows are gone (r4 removes the now-empty Settings sections).
- Every Patterns section degrades honestly on thin data (no fabricated trend) —
  reuse the existing not-enough-data states.
- `screen_nav.dart`: `patterns_tab` surface added, accuracy surface re-pointed;
  sweeps green.
- Non-diagnostic framing preserved — no new claims, copy tests green.

**Tests required.** `patterns_tab_test.dart`; a11y sweeps green.

**Risk.** Medium.

**Depends on.** r3a.

---

## r4 — Settings is only settings

**Goal.** Strip features out of `settings_page.dart` so it holds settings only,
and group the data/sharing rows.

**Shape.**

- **Keeps:** Appearance (theme, app icon), Pronouns, Privacy & security (PIN,
  decoy PIN, biometric unlock, lock-after-inactivity, auto-delete/retention,
  privacy policy, privacy basics), Accessibility (reduce spoken detail),
  Notifications.
- **Removed** (now live in Patterns via r3b): the Cycle → "Prediction accuracy"
  row and the Modes section.
- **New "Data & sharing" screen** (one Settings row → its own screen): Backup &
  restore, Export report for a doctor, Connect a health app + "differences to
  review". These three move off the flat Settings list.
- Pregnancy loss & birth: the Settings → Cycle pointer is dropped (it's in the
  Calendar overflow per r3a); keep the section only if it still has a row.

**Acceptance criteria.**

- Settings has no feature screens left inline — only settings + the one "Data &
  sharing" entry.
- Every relocated destination is still reachable and every deep link / test
  path updated.
- `screen_nav.dart`: `data_and_sharing` surface added, the "Apps & export"
  health surfaces re-pointed; sweeps green.

**Tests required.** `settings_page_test.dart` updated; `data_and_sharing_test.dart`;
a11y sweeps green.

**Risk.** Medium.

**Depends on.** r3b.

---

## r5 — Aesthetic consistency pass

Split into three PRs; each independently shippable.

### r5a — Cards & colour

- Route every home / Patterns card through `Card` (the theme already defines
  elevation 0, `surfaceContainerLow`, radius **16**); delete the hand-rolled
  `Container` + `BorderRadius.circular(12)` cards. One radius everywhere.
- One accent, rest neutral: the forecast card keeps `primaryContainer`;
  everything else on a screen is a neutral `surfaceContainer*`. The overdue
  state gets a distinct look via a leading icon + a thin `errorContainer`
  accent, **not** a full background flip of the main card.
- Acceptance: `a11y/theme_contrast_test.dart` green; no card at radius ≠ 16; a
  screenshot/gold diff review by the Orchestrator.

### r5b — Lists, empty states, motion

- Any remaining eager-built long list → `ListView.builder` / slivers.
- One shared empty-state widget (icon + line + optional CTA) replacing the bare
  `Text('…')` empty states (≈ 8 sites).
- Subtle `AnimatedSize` + fade when conditional cards appear/disappear
  (`ForecastArea` swaps, `_CorrectionNotice`, mode strip) — gated on the
  platform reduce-motion flag.
- Acceptance: reduce-motion path shows no animation; a11y sweeps green.

### r5c — Calendar interactions

- Horizontal swipe between months; "jump to today"; keep the chevrons.
- Acceptance: keyboard-nav sweep green; swipe + chevron reach the same state.

**Risk.** Low–medium, broad surface.

**Depends on.** r3a (r5a/b), r3a (r5c).

---

## Deferred to backlog (not in this pass)

- **4-phase cycle-wheel palette tokens.** The wheel maps the 4 phases to
  `primary / secondary / tertiary / outline` — three near-identical greens from
  one sage seed plus a grey, so the glance doesn't read. Define 4 explicit
  low-chroma, hue-spaced, AA-verified phase tokens (sage / teal / warm-sand /
  muted-clay register), `theme_contrast_test.dart` extended as the gate. Its own
  small design task — risk of drifting toward the "flowery" look the product
  rejects, so keep chroma low and verified. Not blocking the IA work.
- **Day-cell simplification.** Today's 40px cell packs day number + a
  4-segment flow bar + a symptom dot — cramped at 2.0× text. Reduce to number +
  one intensity-coloured underline + one symptom dot; move the 4-segment detail
  into the day-log sheet.
