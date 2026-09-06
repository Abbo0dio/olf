# Plan

The living roadmap for olf, split out of the old monolithic `DEVELOPMENT_PLAN.md`
(2026-09-06). It says *in what order* and *at what stage* each piece is built;
[`../../requirements.md`](../../requirements.md) is the source of truth for *what*
the product must do.

| File | Holds |
|---|---|
| `conventions.md` | How the plan is used, guiding principles, foundational technical decisions. Stable — read once. |
| `architecture.md` | Terse codebase map — module layout, load-bearing seams + their files, cross-cutting infra, CI gates. What a cleared/compacted Worker re-orients from. Refreshed at each phase close. |
| `overview.md` | The phase table: theme, status, gate to move on. The phase-history ledger. |
| `phases/phase-00.md` … `phase-13.md` | One file per phase: the phase frame (goal, requirement refs, exit gate, phase-wide constraints) and every task spec for that phase — goal, acceptance criteria, tests, notes, build detail. |
| `decisions.md` | Append-only decisions log (newest first). |
| `backlog.md` | Follow-ups and ideas not yet scheduled into a phase. |
| `open-questions.md` | Unresolved questions; graduate to `decisions.md` when answered. |
| `cross-cutting.md` | Always-on concerns checked every phase (compliance ledger, release readiness, engineering hygiene). |
| `orphaned.md` | Abandoned branches, superseded designs, cut features. |

**Task status is not in these files.** Every task's live status — `TODO` /
`IN PROGRESS` / `IN REVIEW` / `DONE` / `BLOCKED` / `DEFERRED` / `CUT`, plus the
owning worker, worktree, branch, PR, and squash SHA — lives in
[`../../.herdsman/state.md`](../../.herdsman/state.md), written **only by the
Orchestrator** (herdsman workflow) at dispatch and at merge. A phase file that is
closed freezes its final per-task outcomes into its own `### Notes`; an open
phase's task status is read from `state.md`.

Cross-references between tasks are bare IDs (`Depends on: p5.1a`), resolved via
the target phase file's task list. `overview.md` is authoritative for
phase-level status; `state.md` `## Now` is authoritative for "where are we this
minute".
