<!--
Title: "<task-id> — <short summary>"  e.g. "p0.1 — Initialise repository & workflow"
One worktree = one task = one PR. See CONTRIBUTING.md §3.
-->

## Task

- **Task ID:** <!-- p0.1 -->
- **Development plan entry:** <!-- link to the section in DEVELOPMENT_PLAN.md -->
- **Depends on:** <!-- task IDs or "none" -->

## What this slice does

<!-- One or two sentences: what a user (or contributor) can do after this merges. -->

## Acceptance criteria — and how each was verified

<!-- Copy the acceptance criteria from the task. For EACH, say exactly how it was verified
     (test name, manual step, screenshot, command output). -->

| Criterion | How verified |
|-----------|--------------|
|           |              |

## Definition of Done

Tick every box, or replace `[ ]` with `n/a — <reason>`.

- [ ] Acceptance criteria are met and demonstrated above.
- [ ] **Automated tests** exist and pass: unit for logic; widget/UI for screens; integration
      for any multi-screen flow. New code does not drop overall coverage.
- [ ] **No third-party advertising or analytics SDK** added, transitively or otherwise
      (`requirements.md` §3). Dependency-audit check passes.
- [ ] **Privacy**: no health data written unencrypted; no PHI in logs, crash traces, or
      notification text.
- [ ] **Accessibility baseline**: interactive elements labelled for screen readers; text
      scales; contrast ≥ 4.5:1; touch targets adequate.
- [ ] **Dark mode** and **gender-neutral, non-heteronormative copy** for any new UI.
- [ ] Works **offline / on-device**. No feature silently requires a network call.
- [ ] Runs acceptably on a **low-end device** (`DEVELOPMENT_PLAN.md` §3 budget).
- [ ] **`DEVELOPMENT_PLAN.md` updated**: status set to `IN REVIEW`, PR linked, Log line added,
      and any schema/library/edge-case detail locked in by this slice.

## Test output

<!-- Paste the passing summary line(s), e.g. "All tests passed!" / "00:12 +14: All tests passed!" -->

```
```

## Foundational decisions changed

<!-- If this PR changes anything in DEVELOPMENT_PLAN.md §3, list it here and confirm the
     Decisions Log (§7) was updated. Otherwise: "none". -->

## Reviewer notes

<!-- Anything a reviewer should focus on, known limitations, follow-up TODOs added. -->
