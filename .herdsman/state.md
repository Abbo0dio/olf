# herdsman state

Live build state. **Written only by the Orchestrator**, at dispatch and at merge.
Task status is here, never in `docs/plan/`. See `docs/plan/README.md` for the
plan layout and `.claude/skills/herdsman/` for the workflow.

## Now

Phase 6 — Health-platform interop & doctor export — IN PROGRESS · main @ `2db45db` · current slice p6.5 (last of Phase 6, dispatched to Worker 1)

## Workers

| W | agent    | tab   | status   | slice | worktree        |
| 1 | worker-1 | w6:t2 | building | p6.5  | ../olf-wt/p6.5  |

## Tasks

Current phase (6) + previous phase (5). Closed-phase task detail is frozen into
`docs/plan/phases/phase-05.md` / `phase-06.md`.

| ID | status | PR | SHA | log |
| p5.1a | DONE | #54 | `777e02e` | 2026-09-03 — a11y guideline harness + semantics/focus; test-only, no lib defect. |
| p5.1b | DONE | #55 | `f9dfaa6` | 2026-09-03 — text scaling/reflow to 2.0×; one lib fix (symptom_day_sheet action row). |
| p5.1c | DONE | #56 | `a9e9102` | 2026-09-03 — contrast + tap targets + keyboard nav + accessibility-conformance.md; no lib change. |
| p5.2 | DONE | #57 | `bf14dec` | 2026-09-03 — caption/transcript type-level stub for Phase 11 media. |
| p5.3 | DONE | #58 | `faa03fb` | 2026-09-03 — reduce-spoken-detail control + decoy-safe inactivity auto-lock. |
| p5.4 | DONE | #59 | `dbfd103` | 2026-09-03 — discreet alternate app icon/name via hand-rolled `olf/app_icon` channel; no dep, no new permission. |
| p5.5 | DONE | #60 | `23560d2` | 2026-09-03 — perf budget doc + `perf-budget` CI job (APK size + log-a-period ≤2 taps HARD; cold-start nightly non-blocking). |
| p5.6 | DONE | #61 | `8644dce` | 2026-09-03 — drift migration test matrix v1–v6 + backup/restore-across-migration round trip. |
| Phase 5 close | DONE | #62 | `14b68d2` | 2026-09-03 — Phase 5 CLOSED; exit gate MET; 2 open §9 a11y follow-ups (SC 2.5.7, SC 4.1.3). |
| p6.1 | DONE | #65 | `ed81ac5` | 2026-09-05 — interop foundation: `HealthPlatformGateway` + `FakeHealthPlatformGateway` + pure `ImportReconciler` + schema v6→v7 provenance cols (`source`/`externalId` on bbt_entries + daily_flows). `core`-only, no dep. Doc fixes folded in `e7b308d`. |
| p6.2 | DONE | #66 | `76c31cd` | 2026-09-05 — Apple HealthKit gateway (iOS): hand-rolled `olf/health` MethodChannel + Swift `HealthKitBridge`, no dep, no SDK-floor bump, ATS untouched. `setTemp`/`setFlow` gained `source`/`externalId`; `+allEntries()`/`allFlows()`. |
| p6.3 | DONE | #67 | `de46108` | 2026-09-05 — Android Health Connect gateway: hand-rolled Kotlin bridge on `MainActivity`, same wire contract. `androidx.health.connect:connect-client:1.1.0` as a Gradle dep (not a pub package — `pubspec.lock` clean); `minSdk` 24→26; 4 `android.permission.health.*`. Shared `MethodChannelHealthGateway` base + `sourceTag`. New `docs/health-platform-interop.md`. (Plan had said IN REVIEW; it merged.) |
| p6.4 | DONE | #69 | `2db45db` | 2026-09-06 — Two-way sync: write-back after every flow/BBT log/edit (`externalId` sticky across an edit so a previously-imported day updates its platform record in place, no dupe; edit still flips `source`→`manual` — the p6.1 deferral), per-source status surface (connected · last-sync "N min ago" · counts · "N differences to review"; `reduceSpokenDetail`-redacted), new `conflict_review_screen.dart` (list + keep-mine / use-theirs / dismiss, no bulk ops). **v1 = manual "Sync now" only** — on-open/resume sync deferred (backlog). Retention respected both directions (purge-before-sync via `retentionController.sweepNow()`; cutoff clamps import window + filters push-out). Reconciler: value-already-agrees is now a skip regardless of source (absorbs the write-back echo); manual-value protection unchanged. In-memory conflict store (`// SHORTCUT`, backlog). No dep / no schema / no permission / no manifest / no CI change. CI Format bounced once (worker's local `dart format` under-reported — `analysis_options.yaml` env bug); fixed in `9d3d403`, squashed into `2db45db`. core 573 / app 426. |
| p6.5 | IN PROGRESS | — | — | Worker 1 · worktree `../olf-wt/p6.5` · branch `feat/p6.5-doctor-report` off `2db45db` (dispatched 2026-09-06). Doctor-ready offline PDF report — pure `core` `ClinicalReport` + `app` render via `pdf` pkg (§5 pre-approved in dispatch: conditional on dependency-audit green + Apache-2.0 + no native code + no SDK-floor bump + no `printing`; STOP if any fails). p1.10 SAF seam; neutral filename; purge-before-export; "not a medical device" disclaimer. Last slice of Phase 6. |

## In-flight PRs

_(none)_

## Notes

- Abandoned/merged remote branches to prune (Orchestrator's `git push --delete` is classifier-blocked — user prunes): `feat/p6.4-two-way-sync` @ `55023d8` (abandoned, no PR); `feat/p6.4-two-way-sync-v2` (merged #69, auto-delete failed — the worker's `../olf-wt/p6.4` worktree still pins the local ref; gone on next dispatch). Plus the pre-migration stale list: the Phase 5 `feat/p5.*` batch, `docs/phase-5-close`, `chore/release-v1.1.0`, `feat/p1.12-cycle-wheel`, `feat/p6.1-interop-foundation`, `feat/p6.2-healthkit-gateway`, `feat/p6.3-health-connect-gateway`, `chore/plan-herdsman-migration` (already deleted by `--delete-branch`).
- v1.1.0 is the current release (tag on `6820cd2`). Versioning policy: `docs/plan/decisions.md` (2026-09-04). `1.x` = alpha until the last phase closes; `2.0.0` = beta cut at close.
- **state.md push policy (user decision 2026-09-06):** `protect-main` forbids Orchestrator direct-push to `main`. So `.herdsman/state.md` claim/merge edits are committed to **local `main` only** during a phase and folded into the **phase-close PR**. Between merges, `origin/main`'s copy of this file lags — local `main` is authoritative. After each Worker squash-merge, `git pull --rebase` the local bookkeeping commits onto the advanced `origin/main`.
