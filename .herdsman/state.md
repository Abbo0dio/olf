# herdsman state

Live build state. **Written only by the Orchestrator**, at dispatch and at merge.
Task status is here, never in `docs/plan/`. See `docs/plan/README.md` for the
plan layout and `.claude/skills/herdsman/` for the workflow.

## Now

Phase 6 — Health-platform interop & doctor export — **DONE (2026-09-06)** · main @ `ea585b1` (origin) / local `main` ahead with the Phase 6 bookkeeping + close, going up as the `docs/phase-6-close` PR. **Phase 7 — Life-stage & condition modes — NOT YET PLANNED** (next: expand its one-liners into task rows on `main`, then dispatch p7.1).

## Workers

| W | agent    | tab   | status | slice | worktree |
| 1 | worker-1 | w6:t2 | idle   | —     | —        |

## Tasks

Just-closed phase (6). Phase 5 detail is frozen in `docs/plan/phases/phase-05.md`;
its rows were dropped here at the Phase 6 close. Phase 6 rows stay until Phase 7
is planned. Closed-phase task detail is frozen into `docs/plan/phases/phase-06.md`.

| ID | status | PR | SHA | log |
| p6.1 | DONE | #65 | `ed81ac5` | 2026-09-05 — interop foundation: `HealthPlatformGateway` + `FakeHealthPlatformGateway` + pure `ImportReconciler` + schema v6→v7 provenance cols (`source`/`externalId` on bbt_entries + daily_flows). `core`-only, no dep. Doc fixes folded in `e7b308d`. |
| p6.2 | DONE | #66 | `76c31cd` | 2026-09-05 — Apple HealthKit gateway (iOS): hand-rolled `olf/health` MethodChannel + Swift `HealthKitBridge`, no dep, no SDK-floor bump, ATS untouched. `setTemp`/`setFlow` gained `source`/`externalId`; `+allEntries()`/`allFlows()`. |
| p6.3 | DONE | #67 | `de46108` | 2026-09-05 — Android Health Connect gateway: hand-rolled Kotlin bridge on `MainActivity`, same wire contract. `androidx.health.connect:connect-client:1.1.0` as a Gradle dep (not a pub package — `pubspec.lock` clean); `minSdk` 24→26; 4 `android.permission.health.*`. Shared `MethodChannelHealthGateway` base + `sourceTag`. New `docs/health-platform-interop.md`. (Plan had said IN REVIEW; it merged.) |
| p6.4 | DONE | #69 | `2db45db` | 2026-09-06 — Two-way sync: write-back after every flow/BBT log/edit (`externalId` sticky across an edit so a previously-imported day updates its platform record in place, no dupe; edit still flips `source`→`manual` — the p6.1 deferral), per-source status surface (connected · last-sync "N min ago" · counts · "N differences to review"; `reduceSpokenDetail`-redacted), new `conflict_review_screen.dart` (list + keep-mine / use-theirs / dismiss, no bulk ops). **v1 = manual "Sync now" only** — on-open/resume sync deferred (backlog). Retention respected both directions (purge-before-sync via `retentionController.sweepNow()`; cutoff clamps import window + filters push-out). Reconciler: value-already-agrees is now a skip regardless of source (absorbs the write-back echo); manual-value protection unchanged. In-memory conflict store (`// SHORTCUT`, backlog). No dep / no schema / no permission / no manifest / no CI change. CI Format bounced once (worker's local `dart format` under-reported — `analysis_options.yaml` env bug); fixed in `9d3d403`, squashed into `2db45db`. core 573 / app 426. |
| p6.5 | DONE | #70 | `ea585b1` | 2026-09-06 — Doctor-ready offline PDF report. `pdf ^3.12.0` added (Apache-2.0, direct main) — all §5 conditions met: dependency-audit green with the 7-pkg transitive subtree, pure Dart, no plugin, no SDK-floor bump, no `printing`; APK-size budget green. Pure `core/lib/src/export/clinical_report.dart` (`ClinicalReport` + `buildClinicalReport`, `generatedOn` injected, no `DateTime.now()`); `SymptomRepository.allTypes()` (archived included). `app`: `report_pdf.dart` (single A4, Helvetica core font, hand-drawn temp chart, `// SHORTCUT _ascii()` non-Latin glyph drop → backlog), `report_providers.dart` (purge-before-export via `sweepNow()`, neutral `olf-report-YYYY-MM-DD.pdf`), `export_report_screen.dart` (range picker + preview, new `screen_nav.dart` surface #20). `BackupFileGateway.writeBackup`→ generic `saveFile()` — backup + report share the SAF seam. "Apps & export" section now always shown. threat-model + release-checklist updated. No schema/permission/manifest/CI change. core 586 / app 436. |
| Phase 6 close | DONE | (this PR) | — | 2026-09-06 — Phase 6 CLOSED; exit gate MET (all 5 clauses → slice + PR# + SHA in `docs/plan/phases/phase-06.md`); `overview.md` row 6 → DONE. Phase-wide: one schema bump (p6.1 v6→v7), `health` pkg evaluated+rejected (both gateways hand-rolled), `pdf` added for p6.5, `core` stayed Flutter-free / `DateTime.now()`-free. 4 backlog deferrals (on-open sync, delete propagation, persisted conflict store, bundled Unicode PDF font). |

## In-flight PRs

_(none — `docs/phase-6-close` PR opens after this commit)_

## Notes

- Abandoned/merged remote branches to prune (Orchestrator's `git push --delete` is classifier-blocked — user prunes): `feat/p6.4-two-way-sync` @ `55023d8` (abandoned, no PR); `feat/p6.4-two-way-sync-v2` (merged #69) and `feat/p6.5-doctor-report` (merged #70) — both auto-delete-failed because the worker's `../olf-wt/p6.4` / `../olf-wt/p6.5` worktree still pins the local ref; gone on next dispatch. Plus the pre-migration stale list: the Phase 5 `feat/p5.*` batch, `docs/phase-5-close`, `chore/release-v1.1.0`, `feat/p1.12-cycle-wheel`, `feat/p6.1-interop-foundation`, `feat/p6.2-healthkit-gateway`, `feat/p6.3-health-connect-gateway`, `chore/plan-herdsman-migration` (already deleted by `--delete-branch`).
- v1.1.0 is the current release (tag on `6820cd2`). Versioning policy: `docs/plan/decisions.md` (2026-09-04). `1.x` = alpha until the last phase closes; `2.0.0` = beta cut at close.
- **state.md push policy (user decision 2026-09-06):** `protect-main` forbids Orchestrator direct-push to `main`. So `.herdsman/state.md` claim/merge edits are committed to **local `main` only** during a phase and folded into the **phase-close PR**. Between merges, `origin/main`'s copy of this file lags — local `main` is authoritative. After each Worker squash-merge, `git pull --rebase` the local bookkeeping commits onto the advanced `origin/main`.
