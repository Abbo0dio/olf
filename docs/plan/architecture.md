# Codebase map

Terse orientation for a cleared/compacted Worker — read once, skim per dispatch.
One line per entry. Verified against the tree; refreshed at each phase close.
Deeper rules live in `conventions.md`; task status in `.herdsman/state.md`.

## Top-level layout

- `core/` — package `olf_core`, **pure Dart, no Flutter, no `DateTime.now()`**. Date math, cycle engine, predictors, repositories (interface + drift impl), DB schema + migrations.
- `app/` — package `olf_app`, Flutter. Screens/widgets (Riverpod), encrypted DB layer, platform channels, notification scheduling, a11y test harness.
- `.github/workflows/` + `.github/scripts/` — CI gates (see below).
- `docs/plan/` — this plan set. `requirements.md` (root) — the spec. `scripts/cut_release.sh` — release cut.
- `core/**/*.g.dart` — committed drift codegen; CI fails if stale.

## core/ modules (`core/lib/src/`)

- `date_math.dart` — day arithmetic, `dateOnly`, `daysBetween`. The clock is always injected.
- `cycle/` — `cycle_derivation.dart` (`deriveCycles`, `CycleStats`, `CycleRegularity`), `cycle_phase.dart` (`cyclePhase`), `pregnancy_event.dart` (`PregnancyEndKind`, `mostRecentPregnancyEnd`, `pregnancyRecoveryState`).
- `prediction/` — **seam: `predictor.dart` `abstract interface class Predictor` → `CyclePrediction`**. `robust_predictor.dart` (v1), `adaptive_predictor.dart` (`AdaptivePredictor implements Predictor`, v2 correctable, same seam), `prediction_delta.dart`, `date_range.dart`.
- `backtest/` — `backtest_harness.dart`, `backtest_metrics.dart`, `synthetic_history.dart`, `correction_response.dart` (Phase 3 calibration; not shipped in-app).
- `db/` — `app_database.dart` (drift `AppDatabase`, **`schemaVersion => 7`**, `MigrationStrategy get migration`), `tables.dart` (incl. `enum CycleEventType {periodStart, pregnancyLoss, birth}`), `database_key_store.dart`, `app_database.g.dart`.
- repositories — pattern: `<x>/<x>_repository.dart` (interface) + `<x>/drift_<x>_repository.dart` (impl). Covers `symptom/`, `settings/` (`app_settings` KV — typed-key seam for mode flags etc.), `meds/`, `mucus/`, `bbt/`, `flow/`, `period/`, `reminders/`, `repository/` (cycle events).
- `health/` — **interop seam: `health_platform_gateway.dart` `abstract class HealthPlatformGateway`**. `health_sample.dart` (`HealthSampleType` + `olf/health` wire tokens), `import_reconciler.dart` (pure reconcile engine: `externalId` then `(type, day)`; manual-value disagreement is always a conflict).
- `export/` — `clinical_report.dart` (pure `ClinicalReport` + `buildClinicalReport`, `generatedOn` injected) — doctor PDF is built app-side.
- `modes/` — Phase 7 life-stage modes. `life_stage_mode.dart` (`enum LifeStageMode` p7.1–p7.8, each owns `app_settings` key `mode.<name>`), `postpartum_cycle_return.dart` (pure derivation, p7.1), `gestational_age.dart` (pure GA maths — `PregnancyStartReference.lmpAnchor` is the one conversion seam for LMP/dueDate/conception, p7.2a), `pregnancy_week_notes.dart` (bundled wk 0–42 copy, p7.2a), `daily_fertility_score.dart` (`dailyFertilityScore(...)` — TTC score layered on the p3 estimate + BBT/mucus, no second engine, p7.3), `birth_control_recalibration.dart` (`deriveBirthControlRecalibration(...)` + `BirthControlMethodHormonal.isHormonal` — withhold-the-forecast read, p7.8), `perimenopause_transition.dart` (`derivePerimenopauseTransition({periods, today})` → `PerimenopauseTransitionRead?` — pure variability-trend + descriptive stage read over `deriveCycles`/`CycleStats`/gap logic; output is two enums + plain facts, **NO numeric score — §9(12)**; predictor untouched, p7.7), **`cycle_phase_correlation.dart` — the reusable correlation core: `PhaseEvent{day,category}` → `cyclePhaseCorrelations({events,cycles,today})` → `List<PhaseCorrelation>`; descriptive only (rate-normalised concentration, no p-values); p7.5–p7.7 parameterise it (p7.4)**.
- `cycle/cycle_phase.dart` — `currentCyclePhase(...)` (p1.12) + **`cyclePhaseTimeline(cycles,{today})`** — retrospective per-cycle phase segments anchored on real logged next-period dates; the input to `cyclePhaseCorrelations` (p7.4). `bbt/thermal_shift.dart` — retrospective `thermalShift(...)` ovulation-confirmation primitive (p7.3, not a forecaster).
- `security/` — `auto_lock.dart`, `pin.dart`, `pin_store.dart`. `backup/` — `backup_cipher.dart`, `backup_document.dart`, `backup_service.dart` (encrypted export/restore). `retention/` — `retention_service.dart`, `retention_window.dart` (auto-delete). `personalization/pronouns.dart`, `a11y/` (`captions.dart`, `contrast.dart`).

## app/ modules (`app/lib/src/`)

- `main.dart` → `app_gate.dart` (lock/unlock gate). `providers.dart` — root Riverpod wiring (`appDatabaseProvider`).
- `data/` — **encrypted DB seam**: `encrypted_database.dart` (SQLCipher via `sqlcipher_flutter_libs`; refuses to open unencrypted), `vault_database_opener.dart` (`abstract interface class VaultDatabaseOpener`, fakeable), `secure_storage_key_store.dart` (key in `flutter_secure_storage`).
- `net/olf_http_client.dart` — the single outbound-HTTP chokepoint (p2.6 TLS pinning point; currently no network feature uses it).
- `health/` — `health_channel.dart` (`MethodChannel('olf/health')` wrapper), `health_gateway_base.dart` + `healthkit_gateway.dart` (iOS) + `health_connect_gateway.dart` (Android) + `unavailable_health_gateway.dart`, `health_write_back.dart`, `conflict_review_screen.dart`, `health_providers.dart`.
- `reminders/` — **seam: `reminder_scheduler.dart` `abstract interface class ReminderScheduler`** → `local_notification_reminder_scheduler.dart`. `reminder_copy.dart` / `notification_copy.dart` (locked behind a content test, no PHI), `quiet_hours_providers.dart`, `reminder_controller.dart`.
- `security/` — `screen_security.dart`, `privacy_shield.dart`, `biometric_gateway.dart` (+ `local_auth_*` impl), `pin_unlock_screen.dart`.
- screens — one dir per feature: `period/` (calendar `period_calendar_page.dart`), `cycle/` (`cycle_wheel.dart`), `prediction/` (`prediction_providers.dart`, `accuracy_page.dart`), `symptom/`, `flow/`, `bbt/`, `mucus/`, `meds/`, `pregnancy/`, `modes/` (`modes_page.dart` + `mode_catalog.dart` — the Phase 7 mode list/router; `mode_offer.dart`, `postpartum_screen.dart`, `support_resources_*`, `pregnancy_*` (week view, start-ref sheet, providers — `pregnancy.start_reference` KV; `pregnancy_symptoms.dart` — curated list + `PregnancySymptomsScreen`, logs via the p1.5 repo, p7.2b; `ttc_screen.dart` + `ttc_providers.dart` p7.3; `pcos_screen.dart` + `pcos_mode_providers.dart` p7.4; `birth_control_recalibration_screen.dart` + `_providers.dart` (`mode.birthControlSwitch.dismissedAt` KV) p7.8; **`correlation_chart.dart` `CorrelationChart` — the shared cycle-phase-banded bar, reused by p7.5–p7.7 (p7.4)**; `period_calendar_page.dart` prediction-card gate is composed across modes: `!pregnancyModeOn && !bcRecalActive && !perimenopauseGapSuppress` (`_PerimenopausePausedNote` past a long gap / 12+ months, p7.7), plus `pcosMode` + `perimenopauseMode` wording flags threaded through `_PredictionCard`/`_CycleStatsCard`/`_History` and `cycle_format.dart` (`summariseStats`/`cycleLengthNote`))), `export/` (`report_pdf.dart`, `export_report_screen.dart`), `backup/`, `retention/`, `onboarding/`, `settings/` (`settings_page.dart` — hub), `home_page.dart`, `appearance/` + `theme/` (dark mode), `personalization/`.
- `export/report_pdf.dart` — `pdf` pkg, built-in Helvetica core font, hand-drawn chart.

## Test harness / sweeps

- `app/test/support/` — `harness.dart` (`pumpOlf`, `memoryDb`), **`screen_nav.dart` (`screenSurfaces` list — every screen registers one `Surface`; the five a11y sweeps + dark mode run over all of them)**, `a11y.dart`, `text_scaling.dart` (1.0/1.5/2.0×), `fake_reminder_scheduler.dart`.
- `core/test/db/` — `migration_matrix_test.dart` (every schemaVersion pair) + per-feature `*_migration_test.dart`. New schema change ⇒ extend the matrix + a backup round-trip in the same PR.
- `core/test/*_doc_test.dart` — `threat_model_doc_test.dart`, `health_interop_doc_test.dart` (docs must carry a current-phase entry).
- `app/integration_test/` — on-device smoke (`log_period_test.dart`, `log_symptoms_test.dart`); runs in the nightly matrix, not PR CI.

## CI gates

- `ci.yml` (checks aggregate to **`CI OK`**): Detect workspace · Format (`dart format --set-exit-if-changed`) · Analyze (`--fatal-infos --fatal-warnings`, incl. committed-codegen-current) · Test (core units + app widget) · **Dependency audit** (`.github/scripts/dependency_audit.dart` — dep denylist, no ad/analytics SDK, Android permission diff, transport-security assertions; also fails on stale `pubspec.lock`) · Build (macos→iOS, ubuntu→APK, + install-size §3) · **Perf budget** (`apk_size_budget.dart` vs baseline; `cold_start_budget.dart`).
- `nightly-integration.yml` — `integration_test/` on a real Android emulator (matrix API level) + iOS simulator.
- `dependency-report.yml` — scheduled dep-graph report. `release.yml` — tag → signed build.
- Branch protection: `main` requires a PR + green `CI OK`; no bypass. The Orchestrator cannot direct-push (see `.herdsman/state.md` push policy).
