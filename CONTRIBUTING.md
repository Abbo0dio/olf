# Contributing to **olf**

This project is built **one complete, tested, shippable slice at a time**. We do not build a
skeleton and flesh it out later. A feature is designed → built → tested → reviewed → merged →
marked `DONE`, and only then does the next feature start.

The authoritative roadmap is [`DEVELOPMENT_PLAN.md`](./DEVELOPMENT_PLAN.md). Product scope lives
in [`requirements.md`](./requirements.md). This file is the day-to-day workflow contract; it
mirrors §1 of the development plan. If the two ever disagree, the development plan wins — fix
this file.

---

## 0. Toolchain

The Flutter/Dart SDK is pinned with [`mise`](https://mise.jdx.dev) via [`mise.toml`](./mise.toml)
at the repo root. Current pins: **Flutter 3.35.5**, **Dart 3.9.2** (bundled with that Flutter).

- Install the pinned toolchain once: **`mise install`** (run from the repo root).
- Then either prefix every Flutter/Dart command with **`mise exec --`**
  (e.g. `mise exec -- flutter test`, `mise exec -- dart format .`), or run **`mise activate`**
  in your shell so `flutter` / `dart` resolve to the pinned versions automatically.
- CI pins the same version (`FLUTTER_VERSION` in `.github/workflows/ci.yml`). If you change the
  SDK version, change it in **both** places and record it in `DEVELOPMENT_PLAN.md` §7
  (Decisions Log).

---

## 1. Golden rules

1. **No direct commits to `main`.** All work lands via a pull request from a feature branch that
   lives in its own git worktree.
2. **One worktree = one task = one PR.** If a task is too big for a reviewable PR, split it into
   sub-tasks (`p1.4a`, `p1.4b`, …) in `DEVELOPMENT_PLAN.md` *before* starting.
3. **The plan is a living document.** You update `DEVELOPMENT_PLAN.md` *in the same branch* as
   the work — status, Log lines, and any real detail you nailed down (schema, chosen libraries
   and versions, edge cases, follow-ups discovered).
4. **Definition of Done is non-negotiable.** See §4. Every checkbox must hold before a task is
   `DONE`.
5. **Never expand scope silently.** If a slice reveals new work, add new `TODO` rows (in the
   plan or its Backlog), don't grow the current PR.

---

## 2. Status legend

Every task and phase in `DEVELOPMENT_PLAN.md` carries exactly one status. When you change a
status, also append a dated line to that task's **Log**.

| Status        | Meaning |
|---------------|---------|
| `TODO`        | Not started. No branch, no worktree. |
| `IN PROGRESS` | Being actively worked. Must name the worktree, branch, and who/what owns it. |
| `IN REVIEW`   | PR open. Link the PR. |
| `DONE`        | PR merged **and** verified on `main` (tests green, feature manually confirmed). Link the PR. |
| `BLOCKED`     | Cannot proceed. State exactly what it waits on (task ID, decision, external dep). |
| `DEFERRED`    | Intentionally postponed to a later phase. Say why and to when. |
| `ORPHANED`    | Was `IN PROGRESS`, now abandoned. Branch/worktree may still exist and be stale. State why and the disposition. |
| `CUT`         | Decided against. Keep the row for history; say why. |

---

## 3. Workflow: worktree → PR → merge

### 3.1 Claim the task

In `DEVELOPMENT_PLAN.md`, on the task you are about to start:

- Set **Status** to `IN PROGRESS`.
- Fill in **Branch / worktree** and **Owner**.
- Add a dated **Log** line: `YYYY-MM-DD — claimed by <owner>; worktree ../olf-wt/<task-id>.`

### 3.2 Create the worktree from an up-to-date `main`

```sh
git checkout main
git pull --ff-only origin main
git worktree add ../olf-wt/<task-id> -b <branch>
```

Branch naming: `feat/<task-id>-<slug>`, `fix/<task-id>-<slug>`, `chore/…`, `docs/…`.
Example: branch `feat/p1.1-log-period` in worktree `../olf-wt/p1.1`.

### 3.3 Build the slice

- Work only inside your worktree.
- Keep the app runnable and every previously-`DONE` feature working at every commit that could
  be reviewed.
- As you lock decisions down, write them into `DEVELOPMENT_PLAN.md` on this same branch:
  real schema, library names **with versions**, edge cases handled, follow-ups found. If you
  change a **Foundational decision** (§3 of the plan), record it in the **Decisions Log** (§7)
  with rationale, and update dependent tasks — never mid-slice.

### 3.4 Test — see §4

Add the automated tests the task requires. Run the full test suite locally. CI must be green
(see §5 for the current state of CI enforcement).

### 3.5 Open the PR

```sh
git push -u origin <branch>
gh pr create --base main --fill
```

- The PR description must list the task's acceptance criteria and **how each was verified**.
- The PR template checklist (`.github/pull_request_template.md`) is the Definition of Done —
  tick every box or explain why an item is `n/a`.
- In `DEVELOPMENT_PLAN.md`: set the task `IN REVIEW`, link the PR, add a Log line. Push that
  change on the branch.

### 3.6 Review

At least one reviewing pass — a human reviewer or a separate agent, never the author alone.
Address every comment. Re-request review after pushing fixes.

### 3.7 Merge

- **Squash merge only** (enforced by branch protection).
- Delete the branch after merge.

### 3.8 Clean up and close out

```sh
git worktree remove ../olf-wt/<task-id>
```

- Set the task `DONE` in `DEVELOPMENT_PLAN.md`, link the merged PR, add a Log line.
- Verify on `main`: pull, run tests, manually confirm the feature.
- If the slice revealed new work, add `TODO` rows rather than reopening the PR.

---

## 4. Definition of Done

A task is not `DONE` until **all** of these hold (this list is the PR template):

- [ ] Acceptance criteria in the task are met and demonstrated in the PR.
- [ ] **Automated tests** exist and pass: unit tests for logic; widget/UI tests for screens; an
      integration test for any multi-screen flow. New code does not drop overall coverage.
- [ ] **No third-party advertising or analytics SDK** is added, transitively or otherwise
      (`requirements.md` §3). The dependency-audit check passes.
- [ ] **Privacy**: no health data written anywhere unencrypted; no PHI in logs, crash traces,
      or notification text.
- [ ] **Accessibility baseline**: every interactive element is labelled for screen readers;
      text scales; contrast ≥ 4.5:1; touch targets are adequate.
- [ ] **Dark mode** and **gender-neutral, non-heteronormative copy** for any new UI.
- [ ] Works offline / on-device. No feature silently requires a network call.
- [ ] Runs acceptably on a low-end device (performance budget in `DEVELOPMENT_PLAN.md` §3).
- [ ] `DEVELOPMENT_PLAN.md` updated: status, Log, and any detail/schema the slice locked in.

---

## 5. Continuous integration

CI is defined in [`.github/workflows/ci.yml`](./.github/workflows/ci.yml) and runs on every PR
into `main` and every push to `main`.

| Job | What it does |
|-----|--------------|
| **format** | `dart format --set-exit-if-changed` over `core`, `app`, `.github/scripts`. |
| **analyze** | `dart analyze --fatal-infos --fatal-warnings` for `core` and the tooling script; `flutter analyze --fatal-infos --fatal-warnings` for `app`. |
| **test** | `dart test` in `core`; `flutter test --coverage` in `app`. |
| **dependency-audit** | Scans the locked transitive graph (`core` + `app` `pubspec.lock`) against [`.github/dependency-denylist.txt`](./.github/dependency-denylist.txt) and the app's main Android manifest for un-audited permissions. Fails on any match or on a stale committed lock. See [`docs/dependency-audit.md`](./docs/dependency-audit.md). |
| **build** | `flutter build apk --debug` (Ubuntu) and `flutter build ios --debug --no-codesign` (macOS); reports install size to the run summary. |
| **CI OK** | Aggregate. Green iff every job above passed (or legitimately skipped). |

**A PR cannot merge unless `CI OK` is green** — it is a required status check on the
`protect-main` ruleset (added in p0.3). The `detect` job lets the Flutter jobs skip on a
workspace-less branch without turning `CI OK` red.

`pubspec.lock` is committed for both packages. After changing dependencies, run `pub get` and
commit the updated lock in the same PR, or the audit job fails.

### 5.1 Nightly integration tests (not a PR gate)

[`.github/workflows/nightly-integration.yml`](./.github/workflows/nightly-integration.yml) runs
`flutter test integration_test/` on a real Android emulator (API 26 + 34) and a real iOS
simulator, exercising SQLCipher + the platform key store on a real OS image.

| Job | What it does |
|-----|--------------|
| **android-emulator** | Boots a KVM-accelerated x86_64 emulator (`reactivecircus/android-emulator-runner`) per API level and runs `flutter test integration_test/log_period_test.dart` in `app/`. |
| **ios-simulator** | Boots the newest available iPhone simulator on `macos-latest` via `xcrun simctl` and runs the same suite. |

It is triggered by a nightly `schedule:` and by manual `workflow_dispatch` (Actions tab, or
`gh workflow run nightly-integration.yml`). It is **deliberately not** part of `CI OK` and
**does not block PRs** — emulator/simulator boots are slow and occasionally flaky, and the
log→restart→delete round-trip is already covered headless on every PR by
`core/test/db/persistence_test.dart` and `app/test/widget_test.dart`. A red nightly is a bug to
chase, not a merge blocker.

---

## 6. Branch protection

`main` is protected by the repository ruleset **`protect-main`** (`enforcement: active`). See
[`docs/branch-protection.md`](./docs/branch-protection.md) for the exact rules, how to inspect
them, and how to change them. Summary:

- Pull request required to merge; direct pushes to `main` are rejected.
- **`CI OK` status check required** to merge (p0.3).
- **Squash** is the only allowed merge method.
- Linear history required; force-pushes and branch deletion blocked.
- 0 approvals currently required (raise this when there is more than one regular contributor).

---

## 7. Commit and PR conventions

- Commit messages: imperative mood, `type: summary` where practical
  (`feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`).
- Keep commits coherent; the squash-merge commit message is what lands on `main`, so make the
  PR title a good one-line summary.
- Reference the task ID (`p0.1`, `p1.4a`, …) in the branch name and PR title.
