# Plan conventions

How the plan is used, the guiding principles, and the foundational technical
decisions. Stable — agents read this once. **Task status is not here**: it lives
in [`../../.herdsman/state.md`](../../.herdsman/state.md), written only by the
Orchestrator. Cross-references between tasks are bare IDs (`Depends on: p5.1a`),
resolved via the phase file's task list.

### Core rule: slices, not skeletons

We do **not** build a skeleton and then flesh it out. We build **one complete, tested,
shippable increment at a time**:

> Feature X is designed → built → tested → reviewed → merged → marked `DONE`.
> Only then does feature Y start.

Every task below is scoped so that when it merges, the app is still runnable and every
previously-`DONE` feature still works. "Foundation" work (Phase 0) is kept as small as
possible and is immediately followed by a real user-visible slice.

### Status legend

Mark every task and phase with one of:

| Status        | Meaning |
|---------------|---------|
| `TODO`        | Not started. No branch, no worktree. |
| `IN PROGRESS` | Being actively worked. Must name the worktree, branch, and who/what owns it. |
| `IN REVIEW`   | PR open. Link the PR. |
| `DONE`        | PR merged **and** verified on `main` (tests green, feature manually confirmed). Link the PR. |
| `BLOCKED`     | Cannot proceed. State exactly what it waits on (task ID, decision, external dep). |
| `DEFERRED`    | Intentionally postponed to a later phase. Say why and to when. |
| `ORPHANED`    | Was `IN PROGRESS`, now abandoned. Branch/worktree may still exist and be stale. State why and the disposition (delete branch / salvage / supersede). |
| `CUT`         | Decided against. Keep the row for history; say why. |

When you change a status, also append a dated line to that task's **Log**.

### Workflow: worktree → PR → merge

All feature work happens in a **git worktree**, never directly on `main`.

1. **Claim** the task: set it `IN PROGRESS`, fill in the branch/worktree names, add a Log line.
2. **Create the worktree** from an up-to-date `main`:
   ```
   git worktree add ../olf-wt/<task-id> -b <branch>
   ```
   Branch naming: `feat/<task-id>-<slug>`, `fix/…`, `chore/…`, `docs/…`.
   Example: `feat/p1.1-log-period` in worktree `../olf-wt/p1.1`.
3. **Build the slice** inside that worktree. Update this document *in the same branch* with
   any detail you nailed down (schema, chosen libs, edge cases, follow-ups discovered).
4. **Test** — see §1.4. CI must be green.
5. **Open a PR** into `main`. Set task `IN REVIEW`, link the PR. PR description lists the
   acceptance criteria and how each was verified.
6. **Review** — at least one reviewing pass (human or a separate agent). Address comments.
7. **Merge** — squash merge. Delete the branch.
8. **Clean up**: `git worktree remove ../olf-wt/<task-id>`.
9. **Close out**: set task `DONE`, link the merged PR, add a Log line. If the slice revealed
   new work, add new `TODO` rows (here or in the Backlog) rather than expanding scope silently.

One worktree = one task = one PR. If a task is too big for a reviewable PR, split it into
sub-tasks (`p1.4a`, `p1.4b`, …) *before* starting.

### Definition of Done (applies to every task)

A task is not `DONE` until **all** of these hold:

- [ ] Acceptance criteria in the task are met and demonstrated in the PR.
- [ ] **Automated tests** exist and pass: unit tests for logic; widget/UI tests for screens;
      an integration test for any multi-screen flow. New code does not drop overall coverage.
- [ ] **No third-party advertising or analytics SDK** is added, transitively or otherwise
      (`requirements.md` §3). The dependency-audit check (Phase 0) passes.
- [ ] **Privacy**: no health data written anywhere unencrypted; no PHI in logs, crash traces,
      or notification text.
- [ ] **Accessibility baseline**: every interactive element is labelled for screen readers,
      text scales, contrast ≥ 4.5:1, touch targets are adequate. (Full WCAG 2.2 AA audit is
      Phase 5, but slices do not accrue debt.)
- [ ] **Dark mode** and **gender-neutral, non-heteronormative copy** for any new UI.
- [ ] Works offline / on-device. No feature silently requires a network call.
- [ ] Runs acceptably on a low-end device (see performance budget in §3).
- [ ] This document updated: status, Log, and any detail/schema the slice locked in.

### Task entry template

```
#### <ID> — <Short name>
- **Status:** TODO
- **Branch / worktree:** —
- **Owner:** —
- **Depends on:** <task IDs or "none">
- **Requirement refs:** requirements.md §<n>
- **Goal:** One or two sentences. What the user can do after this merges.
- **Acceptance criteria:**
  - …
- **Tests required:** …
- **Notes / detail:** (agent fills this in as work proceeds)
- **Log:**
  - YYYY-MM-DD — created.
```

---

---

1. **Trust is the product.** Privacy and correctable accuracy are features, not compliance chores.
2. **Correctable predictions.** The user can always override the algorithm; fixing a wrong
   prediction visibly improves future ones; a late period never silently "rolls forward".
3. **Local-first.** On-device storage is the default. Cloud is opt-in and zero-knowledge.
4. **No ad/analytics SDKs. Ever.** This is a hard architectural constraint.
5. **Free forever.** olf has no subscription, no paid tier, no billing, and no upsell — ever.
   Every feature, including the AI assistant and advanced insights, is free. Hard product
   constraint, not a launch-phase choice.
6. **Inclusive by default.** Gender-neutral language, optional pronouns, discreet neutral design.
7. **Never lose data.** Robust export/backup; survive OS updates and migrations.
8. **Not a medical device** (unless/until a deliberate FDA program in Phase 12). Clear disclaimers.

---

---

> Agents may change any of these, but must (a) record the change and rationale in the
> **Decisions Log** (§7), (b) update dependent tasks, (c) not do it mid-slice.

| Area | Provisional choice | Why |
|------|--------------------|-----|
| **App framework** | **Flutter (Dart)** | One codebase for iOS + Android; compiles to native ARM (no JS bridge) so it runs well on low-end devices; nothing "phones home" unless we add it, which suits the no-analytics rule; Flutter desktop exists for the future desktop provision. |
| **Architecture** | **Pure-Dart `core` package** (domain models, cycle math, prediction engine, crypto, storage *interfaces*, sync protocol) + **`app` Flutter package** (UI, platform glue). Platform SDK code isolated behind interfaces. | The desktop app (Phase 13) is a *separate*, lean shell that reuses `core` — no desktop code bloats the mobile app. |
| **Local database** | SQLite via `drift`, encrypted at rest (SQLCipher / `sqlcipher_flutter_libs`). | Mature, relational, good migrations story (data-loss requirement). |
| **Secure key storage** | `flutter_secure_storage` (Keychain / Keystore). | DB encryption key never in plaintext. |
| **State management** | Riverpod. | Testable, good for "recompute predictions when data changes". |
| **Local notifications** | `flutter_local_notifications` with per-category channels. | Granular controls are a hard requirement. |
| **Health platform** | `health` plugin (HealthKit / Health Connect), wrapped behind our own interface. | Interop requirement; wrap so we can swap it. |
| **CI** | GitHub Actions: format, analyze, test, dependency-audit, build iOS+Android. | Every PR gated. |
| **Testing** | `flutter_test`, `integration_test`, `mocktail`; golden tests for key screens. | Enforces §1.4. |
| **Source hosting / PRs** | GitHub. Squash merge. Branch protection on `main`. | Matches worktree→PR→merge workflow. |
| **Min target / performance budget** | iOS 15+, Android 8+ (API 26+). Cold start < 2s on a 2019 mid-range Android; log-a-period flow ≤ 2 taps and < 100ms feedback; install size kept small (track it in CI). | "Runs well on most devices"; anti-bloat. |
| **Backend (sync)** | None until Phase 9. MVP is fully on-device. | Local-first; smallest attack surface early. |
| **AI provider** | Undecided — decide in Phase 10. Constraint: no health data to a third party without zero-knowledge / on-device handling. Consult the `claude-api` skill when scoping. | Privacy rule dominates. |

