# Phase overview

| Phase | Theme | Status | Gate to move on |
|-------|-------|--------|-----------------|
| **0** | Repo, workflow, CI, app-runs-and-does-one-real-thing | `DONE` | CI green; a build installs; one real slice merged |
| **1** | MVP core tracking — free, un-paywalled | `DONE` | Core tracking usable end-to-end; correction loop works; backup/restore works |
| **2** | Privacy & security hardening | `DONE` | Lock + decoy + auto-delete + masking shipped and tested; standalone policy live; threat model committed; audit gate enforced as a release blocker |
| **3** | Correctable adaptive prediction engine v2 | `DONE` | v2 shipped behind the unchanged seam: MAE beat on PCOS/postpartum + large calibration gains on every fat-tailed profile (the honest headline is "stops the false precision", per §4); corrections move v2 ~1.7–2.2× v1; no snowballing in-sample or held-out |
| **4** | Notifications & reminders | `DONE` | Per-category channels each independently toggleable; on-device behaviour-timed delivery with a safe fallback, nothing stored; all copy reviewed + locked behind a content test, no PHI; a quiet-hours window that shifts rather than drops; a permanent "stop asking to subscribe" control gated for Phase 10 [reverted 2026-09-02, PR #52 — olf is free-forever]; the p1.7 medication reminder folded onto the one unified path |
| **5** | Accessibility & design polish | `DONE` | WCAG 2.2 AA audit passed; low-end perf verified; discreet icon/name option |
| **6** | Health-platform interop & doctor export | `DONE` | Two-way Apple Health / Health Connect sync; doctor-ready PDF |
| **7** | Life-stage & condition modes | `DONE` | Pregnancy, loss/birth, postpartum, PCOS, endo, PMDD, perimenopause modes shipped |
| **8** | Passive wearable integration | `DONE` | Apple Watch wrist-temp path + Oura/Garmin via the platform + passive cycle-phase inference (backtested, correctable) + multi-source arbitration shipped; watch companion (p8.1b) & direct cloud API (p8.3) deferred to backlog |
| **9** | Optional zero-knowledge encrypted sync | `TODO` | Opt-in multi-device sync; local-first stays default; deletion propagates |
| **10** | AI assistant + advanced insights | `TODO` | AI assistant privacy design documented in the threat model (on-device / zero-knowledge, no health data to a third party); advanced insights are useful and non-alarming — no diagnosis language. Free, like everything else. |
| **11** | Educational content & privacy-safe community | `TODO` | Named-reviewer content system; anonymous community with moderation |
| **12** | Scale & defensibility (ISO 27001, optional FDA) | `TODO` | compliance ledger complete; FDA decision recorded |
| **13** | Desktop app provision (separate, lean) | `TODO` | Separate desktop shell reusing `core`; zero added weight to mobile |

**Roadmap paused after Phase 8 (2026-09-07).** Phases 0–8 are `DONE` and the app is
feature-complete for its current scope. Near-term work is **testing, functionality
hardening, and refinement** of that scope — not new phases. Phases 9–13 stay as the
eventual roadmap and resume when the stabilisation pass is done. The herdsman phase/slice
cadence is on hold; hardening is tracked against `backlog.md` + the §9 follow-up list. See
`decisions.md` (2026-09-07). Release `v1.2.0` brings the downloadable build up to everything
on `main` through the Phase 8 close.

Cross-cutting work (compliance ledger, release/store readiness, threat model) is tracked in `cross-cutting.md`.

---
