# Development Plan — Period & Cycle Tracker ("olf")

> This is the **living roadmap**. It is written for AI agents and human contributors who pick up
> work one slice at a time. It is deliberately **not** hyper-specific: each task is a vertical
> slice, and the agent doing that slice is expected to expand it with real detail (file names,
> library versions, schema, edge cases) **in this document** as they go.
>
> Source of truth for *what* the product must do: [`requirements.md`](./requirements.md).
> This document is the source of truth for *in what order* and *at what stage* each piece is.

---

## 1. How to use this document

### 1.1 Core rule: slices, not skeletons

We do **not** build a skeleton and then flesh it out. We build **one complete, tested,
shippable increment at a time**:

> Feature X is designed → built → tested → reviewed → merged → marked `DONE`.
> Only then does feature Y start.

Every task below is scoped so that when it merges, the app is still runnable and every
previously-`DONE` feature still works. "Foundation" work (Phase 0) is kept as small as
possible and is immediately followed by a real user-visible slice.

### 1.2 Status legend

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

### 1.3 Workflow: worktree → PR → merge

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

### 1.4 Definition of Done (applies to every task)

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

### 1.5 Task entry template

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

## 2. Guiding principles (condensed from `requirements.md`)

1. **Trust is the product.** Privacy and correctable accuracy are features, not compliance chores.
2. **Correctable predictions.** The user can always override the algorithm; fixing a wrong
   prediction visibly improves future ones; a late period never silently "rolls forward".
3. **Local-first.** On-device storage is the default. Cloud is opt-in and zero-knowledge.
4. **No ad/analytics SDKs. Ever.** This is a hard architectural constraint.
5. **Humane monetization.** Core tracking is permanently free and un-paywalled. No post-action
   upsell pop-ups. Easy cancellation. Advanced/AI features only behind the paid tier.
6. **Inclusive by default.** Gender-neutral language, optional pronouns, discreet neutral design.
7. **Never lose data.** Robust export/backup; survive OS updates and migrations.
8. **Not a medical device** (unless/until a deliberate FDA program in Phase 12). Clear disclaimers.

---

## 3. Foundational decisions (PROVISIONAL)

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

---

## 4. Phase overview

| Phase | Theme | Status | Gate to move on |
|-------|-------|--------|-----------------|
| **0** | Repo, workflow, CI, app-runs-and-does-one-real-thing | `DONE` | CI green; a build installs; one real slice merged |
| **1** | MVP core tracking — free, un-paywalled | `TODO` | Core tracking usable end-to-end; correction loop works; backup/restore works |
| **2** | Privacy & security hardening | `TODO` | Lock + decoy + auto-delete + standalone policy shipped; audit gate enforced |
| **3** | Correctable adaptive prediction engine v2 | `TODO` | Handles irregular cycles; backtesting harness + accuracy metrics; corrections visibly improve output |
| **4** | Notifications & reminders | `TODO` | Per-category controls; humane copy; quiet hours; "stop asking" control |
| **5** | Accessibility & design polish | `TODO` | WCAG 2.2 AA audit passed; low-end perf verified; discreet icon/name option |
| **6** | Health-platform interop & doctor export | `TODO` | Two-way Apple Health / Health Connect sync; doctor-ready PDF |
| **7** | Life-stage & condition modes | `TODO` | Pregnancy, loss/birth, postpartum, PCOS, endo, PMDD, perimenopause modes shipped |
| **8** | Passive wearable integration | `TODO` | Apple Watch companion + ≥1 third-party wearable; passive phase inference |
| **9** | Optional zero-knowledge encrypted sync | `TODO` | Opt-in multi-device sync; local-first stays default; deletion propagates |
| **10** | Monetization + AI assistant + advanced insights | `TODO` | Paid tier live; core still free; humane billing; AI assistant privacy-safe |
| **11** | Educational content & privacy-safe community | `TODO` | Named-reviewer content system; anonymous community with moderation |
| **12** | Scale & defensibility (B2B2C, ISO 27001, optional FDA) | `TODO` | B2B2C pilot path; compliance ledger complete; FDA decision recorded |
| **13** | Desktop app provision (separate, lean) | `TODO` | Separate desktop shell reusing `core`; zero added weight to mobile |

Cross-cutting work (compliance ledger, release/store readiness, threat model) is tracked in §6.

---

## 5. Phases & tasks

> Only the near-term phases are broken into task rows. Later phases list their intended slices
> at lower resolution; the agent starting that phase splits them into proper task entries first.

### Phase 0 — Repo, workflow, CI

**Status:** `DONE` · **Goal:** the repo exists, the workflow is enforced, and the app
builds and does exactly one real thing so Phase 1 has something to grow.

#### p0.1 — Initialise repository & workflow
- **Status:** DONE
- **PR:** https://github.com/Abbo0dio/olf/pull/1 (merged)
- **Branch / worktree:** `feat/p0.1-workflow-scaffolding` in `../olf-wt/p0.1`
- **Owner:** worker: phase0
- **Depends on:** none
- **Goal:** `git init`, first commit, GitHub remote, branch protection on `main`, `.gitignore`,
  `CONTRIBUTING.md` capturing the §1 workflow, PR template with the §1.4 checklist.
- **Acceptance criteria:**
  - `main` is protected; direct pushes blocked; PR + green CI required to merge.
    - *Status:* `main` is protected (ruleset `protect-main`, active): PR required, squash-only,
      linear history, no force-push, no deletion, no bypass actors. **Required status checks
      are NOT wired yet** — that is p0.3. Until p0.3 merges, a PR is technically mergeable
      without a green CI run; green CI is mandatory by convention. Documented in
      `docs/branch-protection.md` and CONTRIBUTING.md §5–6.
  - `CONTRIBUTING.md` documents the worktree→PR→merge flow and status legend.
- **Tests required:** n/a (repo scaffolding) — but the CI workflow file is added here.
- **Notes / detail:**
  - Added `CONTRIBUTING.md` — golden rules, status legend (mirrors §1.2), full
    worktree→PR→merge workflow (mirrors §1.3), Definition of Done (mirrors §1.4), CI state,
    branch-protection summary, commit/PR conventions.
  - Added `.github/pull_request_template.md` — task block + acceptance-criteria/verification
    table + the §1.4 DoD checklist + test-output + "foundational decisions changed" section.
  - Added `.github/workflows/ci.yml` — valid YAML, jobs `detect` → `format` / `analyze` /
    `test` / `dependency-audit` / `build` → `ci-ok` aggregate. Flutter-dependent jobs skip
    until the workspace lands in p0.2 (detected via `pubspec.yaml` / `app/pubspec.yaml` /
    `melos.yaml`). `dependency-audit` always runs. `ci-ok` is the single check p0.3 will mark
    required in the ruleset.
  - Added `.github/scripts/dependency_audit.sh` — Phase 0 stub: seed denylist of
    ad/analytics/tracking/crash SDK package names, best-effort scan of `pubspec.lock` when it
    exists, warn-only. p0.3 makes matches fatal, commits the denylist + extension docs, adds
    the deliberately-failing fixture.
  - Added `docs/branch-protection.md` — exact ruleset rules, ruleset id `21675040`, verify
    commands, change procedure. Last confirmed 2026-08-27.
  - Added `mise.toml` at repo root — pins the toolchain: **Flutter 3.35.5**, **Dart 3.9.2**
    (bundled). Verified locally via `mise exec -- flutter --version` / `mise exec -- dart
    --version`. CONTRIBUTING.md §0 tells contributors to run `mise install` and prefix
    Flutter/Dart commands with `mise exec --` (or `mise activate`).
  - SDK pin in CI: `FLUTTER_VERSION=3.35.5` (matches `mise.toml`); p0.2 confirms it still fits
    and records any change in §7 + p0.2 Notes.
  - Follow-ups for p0.3: wire `required_status_checks` → `CI OK`; flesh out `format` /
    `analyze` / `test` / `build` once p0.2 exists; real dependency-audit + failing fixture;
    install-size check (§3 budget).
- **Log:**
  - — created.
  - 2026-08-27 — claimed by worker: phase0; worktree `../olf-wt/p0.1`, branch
    `feat/p0.1-workflow-scaffolding`. Set IN PROGRESS.
  - 2026-08-27 — PR #1 opened (https://github.com/Abbo0dio/olf/pull/1). Set IN REVIEW.
  - 2026-08-28 — PR #1 squash-merged to `main`; CI green on `main`. Set DONE.
  - 2026-08-27 — added `mise.toml` (Flutter 3.35.5 / Dart 3.9.2 pin) from orchestrator +
    CONTRIBUTING.md §0 toolchain instructions.

#### p0.2 — Flutter workspace: `core` + `app`
- **Status:** DONE
- **PR:** https://github.com/Abbo0dio/olf/pull/2 (merged)
- **Branch / worktree:** `feat/p0.2-flutter-workspace` in `../olf-wt/p0.2`
- **Owner:** worker: phase0
- **Depends on:** p0.1
- **Goal:** Melos (or plain path deps) monorepo with a pure-Dart `core` package and a Flutter
  `app` package. App launches to an empty themed home screen (light + dark).
- **Acceptance criteria:**
  - `core` has **no Flutter dependency**.
    - *Status:* `core/pubspec.yaml` (`olf_core`) depends only on `meta`; dev-deps `lints`,
      `test`. No `flutter` / `flutter_test`. Analyzed with plain `dart analyze` and tested with
      plain `dart test` (no Flutter tooling) in CI, which would break if a Flutter import crept
      in.
  - App builds and runs on iOS simulator and Android emulator.
    - *Status:* build verified **in CI** — `build` job runs `flutter build apk --debug`
      (ubuntu) and `flutter build ios --debug --no-codesign` (macos). Local Android/iOS
      build+run was **not** possible on the worker box (no Android SDK; Linux, so no macOS);
      an emulator/simulator smoke-run is left for the reviewer/orchestrator before merge.
  - One trivial unit test in `core` and one widget test in `app` run in CI.
    - *Status:* `core/test/date_math_test.dart` (6 tests over `daysBetween` / `dayCountSince`)
      and `app/test/widget_test.dart` (2 tests: home-screen copy + dark-mode render). Both run
      in the `test` CI job. These gate all future PRs.
- **Tests required:** the two sample tests above; they gate all future PRs.
- **Notes / detail:**
  - **Layout:** plain `path:` dependency monorepo, **not Melos** (decision recorded in §7).
    `core/` = `olf_core` (pure Dart, `version: 0.1.0`); `app/` = `olf_app`
    (`flutter create --org com.olf --platforms ios,android`), depends on
    `olf_core: { path: ../core }`. Root `README.md` documents the layout.
  - **`core` first real code:** `lib/src/date_math.dart` — `dateOnly`, `daysBetween` (DST-safe
    via UTC-normalised midnights), `dayCountSince` (1-based, start = Day 1). Chosen because
    p0.4's home screen needs a "Day N" readout; keeps the sample test non-vacuous.
  - **`app`:** `main.dart` trimmed to `OlfApp` + `HomePage`. Material 3,
    `ColorScheme.fromSeed`, `themeMode: ThemeMode.system`, explicit `theme` + `darkTheme`.
    Provisional neutral seed `0xFF4C6B5A` (not pink/gendered) with a `// TODO(p1.9)` — the real
    design-token/pronoun baseline is p1.9. Home screen shows only an `olf` app bar + centred
    "Nothing logged yet." (p0.4 adds the first action). `olf_core` is a declared dependency;
    first actual consumer is p0.4.
  - **Lints:** `core` uses `package:lints/recommended.yaml` + strict-casts/inference/raw-types;
    `app` keeps `package:flutter_lints`. `flutter analyze --fatal-infos --fatal-warnings` and
    `dart analyze --fatal-infos --fatal-warnings` both clean.
  - **CI:** `ci.yml` updated from the p0.1 stub — `format` now targets `core app`; `analyze`
    and `test` run per-package (plain `dart` for core, `flutter` for app); `build` uses
    `working-directory: app`. `detect` now requires both `core/` and `app/` pubspecs.
    `dependency_audit.sh` stub now scans both packages' `pubspec.yaml`/`.lock` (still
    warn-only; p0.3 makes it real).
  - **SDK:** Flutter 3.35.5 / Dart 3.9.2 (matches `mise.toml` and CI `FLUTTER_VERSION`) —
    verified via `mise exec -- flutter --version`. No change to the provisional pin.
  - **Follow-ups:** (a) `pubspec.lock` stays gitignored (inherited from initial commit); if
    reproducible CI builds want it, commit `app/pubspec.lock` in p0.3. (b) Riverpod is
    **not** added yet (no state to manage) — introduce it with the first stateful screen.
    (c) `integration_test` package added in p0.4.
- **Log:**
  - — created.
  - 2026-08-27 — claimed by worker: phase0; worktree `../olf-wt/p0.2`, branch
    `feat/p0.2-flutter-workspace`. Set IN PROGRESS. Scaffolded `core` + `app`, wired CI,
    added the two sample tests (all green locally).
  - 2026-08-27 — PR #2 opened (https://github.com/Abbo0dio/olf/pull/2). Set IN REVIEW.
  - 2026-08-28 — PR #2 squash-merged to `main`; CI green on `main`. Set DONE.

#### p0.3 — CI gates: format, analyze, test, dependency audit, build
- **Status:** DONE
- **PR:** https://github.com/Abbo0dio/olf/pull/3 (merged)
- **Branch / worktree:** `feat/p0.3-ci-gates` in `../olf-wt/p0.3`
- **Owner:** worker: phase0
- **Depends on:** p0.2
- **Goal:** GitHub Actions pipeline. Add the **dependency-audit** step that fails the build if
  any dependency (transitive included) matches a denylist of ad/analytics/tracking SDKs, or if
  a new network-permission is added without a `// audited:` justification.
- **Acceptance criteria:**
  - PR cannot merge unless format/analyze/test/audit/build all pass.
    - *Status:* `required_status_checks` rule added to the `protect-main` ruleset (id
      `21675040`) requiring the **`CI OK`** aggregate check. `CI OK` is green only if
      format + analyze + test + dependency-audit + build all pass (or legitimately skip).
      Verified via `gh api repos/Abbo0dio/olf/rulesets/21675040`.
  - Denylist + rationale committed; documented how to extend it.
    - *Status:* `.github/dependency-denylist.txt` (38 rules, one-line rationale each,
      grouped analytics / advertising-attribution / crash-telemetry). `docs/dependency-audit.md`
      covers the format (`exact` / `~substring` / `re:regex`), how to add/remove entries, what
      the gate does and does not catch.
- **Tests required:** a deliberately-failing fixture proves the audit step actually blocks.
  - *Status:* `core/test/dependency_audit_test.dart` — 6 tests spawning the audit script over
    fixtures in `core/test/fixtures/`: denylisted-lock → exit 1 (exact + `~` rules);
    clean-lock → exit 0; un-audited manifest permission → exit 1; audited permission → exit 0;
    real repo denylist + committed locks → exit 0; bad invocation → exit 2.
- **Notes / detail:**
  - **Audit implementation:** rewrote the p0.1/p0.2 bash stub as
    `.github/scripts/dependency_audit.dart` (pure `dart:` libs, runs with no `pub get`).
    Arg-driven (`--denylist`, `--lock` ×N, `--manifest` ×N) so CI and the fixture tests share
    one code path. Scans **every** package in a `pubspec.lock` (direct + dev + transitive).
  - **Transitive coverage via committed locks:** `.gitignore` now keeps
    `core/pubspec.lock` + `app/pubspec.lock` (decision in §7). The `dependency-audit` job runs
    `pub get`, fails on lock drift (`git diff --exit-code`), then audits the locked graph +
    `app/android/app/src/main/AndroidManifest.xml`. `src/debug` + `src/profile` manifests are
    Flutter-tooling-managed (not release) and reviewed by eye; iOS ATS review is p2.6.
  - **CI changes vs p0.2:** `format` also covers `.github/scripts`; `analyze` also runs
    `dart analyze` on the tooling script; `dependency-audit` is now a real gated job (was a
    warn-only stub); `build` adds an install-size report to `$GITHUB_STEP_SUMMARY` with a
    250 MiB *tripwire* only — a real budget on a release build is p5.5. `ci-ok` unchanged
    (already the intended required check).
  - **Ruleset:** added `required_status_checks` → `CI OK`,
    `strict_required_status_checks_policy: false` (no forced rebase). All prior rules
    preserved (PR required, squash-only, linear history, no force-push/deletion, 0 approvals).
    `docs/branch-protection.md` + `CONTRIBUTING.md` §5–6 updated.
  - **Follow-ups:** tighten the size tripwire into a real budget on a release build (p5.5);
    make the audit cover native Gradle/CocoaPods deps if any are ever added (p2.8 threat
    model); `integration_test` wiring is p0.4.
- **Log:**
  - — created.
  - 2026-08-27 — claimed by worker: phase0; worktree `../olf-wt/p0.3`, branch
    `feat/p0.3-ci-gates`. Set IN PROGRESS. Built the real audit + failing-fixture tests,
    committed both `pubspec.lock`s, made `CI OK` a required status check on `protect-main`.
  - 2026-08-27 — PR #3 opened. Set IN REVIEW.
  - 2026-08-28 — PR #3 squash-merged to `main`; CI green on `main`; `CI OK` required-check
    active on `protect-main`. Set DONE.

#### p0.4 — Encrypted local store + first real slice: *log that your period started today*
- **Status:** DONE
- **PR:** https://github.com/Abbo0dio/olf/pull/4 (merged)
- **Branch / worktree:** `feat/p0.4-encrypted-store-log-period` in `../olf-wt/p0.4`
- **Owner:** worker: phase0
- **Depends on:** p0.3
- **Requirement refs:** requirements.md §1, §3, §9(1)
- **Goal:** The smallest genuine feature: a one-tap "Period started today" button on the home
  screen writes a `CycleEvent` to the **encrypted** SQLite DB; the home screen shows "Day N"
  since that date; the user can undo/delete it.
- **Acceptance criteria:**
  - DB file is encrypted; key stored in secure storage; app fails safe if key missing.
    - *Status:* `app/lib/src/data/encrypted_database.dart` opens SQLCipher via
      `sqlcipher_flutter_libs`; asserts `PRAGMA cipher_version` is non-empty (refuses to run
      on a plain sqlite3 that would write plaintext). 256-bit key from `Random.secure`, stored
      in Keychain/Keystore via `flutter_secure_storage` (`SecureStorageKeyStore` implementing
      `core`'s `DatabaseKeyStore`). Key missing **and** DB file present → throws
      `MissingDatabaseKeyException`; the UI shows a dead-end "Can't unlock your data" screen
      and writes nothing (widget test `missing key → fail-safe screen`).
  - Logging, viewing, and deleting the event all work and survive an app restart.
    - *Status:* `core/test/db/persistence_test.dart` — write → `close()` → reopen (new
      `AppDatabase` on the same file) → row present → delete → reopen → gone. Widget tests
      cover log→"Day 1", pre-seeded "Day N", and remove→empty. On-device version in
      `app/integration_test/log_period_test.dart` (not in CI — no emulator).
  - Migration framework in place (versioned schema) from the first table.
    - *Status:* `AppDatabase` in `core` — `schemaVersion = 1`, `MigrationStrategy` with
      `onCreate` (createAll), an `onUpgrade` skeleton (empty at v1), and `beforeOpen`
      (`PRAGMA foreign_keys = ON`). `core/test/db/app_database_test.dart` asserts version,
      columns/types, `user_version`, FKs. Process for the first real migration documented in
      `docs/local-database.md`.
- **Tests required:** unit tests for the repository + migration; widget test for the button and
  "Day N" display; integration test for log→restart→still-there→delete.
  - *Status:* core 17 new tests (`app_database` 4, `cycle_event_repository` 6, `persistence` 1,
    plus `date_math` 6 unchanged); app 6 widget tests; 1 device integration test (documented,
    not gated). The headless persistence round-trip stands in for the device integration test
    in CI — see follow-ups.
- **Notes / detail:**
  - **Package split (per §3):** schema + queries + migrations + repositories live in **`core`**
    (`drift` is pure Dart). The **encrypted executor** and **key store** live in **`app`** and
    are handed to `core` through `QueryExecutor` / the `DatabaseKeyStore` interface — `core`
    stays Flutter- and SQLCipher-free so the Phase 13 desktop shell can reuse it. Full write-up
    in `docs/local-database.md`.
  - **Schema v1:** `cycle_events(id, type TEXT enum, date INTEGER unix-seconds, created_at)`.
    `date` is stored date-only (`dateOnly` from `core`) so "Day N" is time-of-day independent;
    `created_at` is an audit trail for future corrections. Only `periodStart` is ever written.
  - **New deps:** `core` → `drift ^2.28`, dev `drift_dev` + `build_runner` + `sqlite3`
    (tests). `app` → `flutter_riverpod ^2.6`, `drift`, `sqlite3`, `sqlcipher_flutter_libs
    ^0.6.5`, `flutter_secure_storage ^9.2`, `path_provider`, `path`; dev `integration_test`.
    None on the denylist; audit passes. **Riverpod is now actually introduced** (§7).
  - **Gotcha:** `sqlcipher_flutter_libs` and `sqlite3_flutter_libs` both ship the same
    `Sqlite3FlutterLibsPlugin` class and collide at Android dex-merge / iOS link time — you
    can use only one. `sqlcipher_flutter_libs` is it (SQLCipher is a superset of SQLite).
    Host/CI widget tests use the system `libsqlite3` instead (`libsqlite3-dev` in the `test`
    job).
  - **Codegen:** drift's `app_database.g.dart` is committed; CI `analyze` regenerates and
    fails on any diff. `core/analysis_options.yaml` excludes `lib/**/*.g.dart`.
  - **"Day N":** `dayCountSince(latestPeriodStart.date, DateTime.now())` (start = Day 1).
  - **Undo/delete:** logging shows an "Undo" SnackBar (deletes the new row); the logged state
    has a "Remove this entry" button with its own Undo (re-logs the same date).
  - **Follow-ups:**
    (a) ~~Wire `app/integration_test/` into CI once emulator CI exists~~ — done in **p0.5**
        (nightly, non-blocking).
    (b) drift schema-snapshot tooling (`drift_dev schema`) lands with the first real migration
        in Phase 1.
    (c) `EncryptedDatabase` opens on the main isolate (`LazyDatabase`); move to a background
        isolate if the DB grows enough to jank the first frame.
    (d) DB lives in `getApplicationSupportDirectory()`; revisit for the p1.10 backup/export.
- **Log:**
  - — created.
  - 2026-08-28 — claimed by worker: phase0; worktree `../olf-wt/p0.4`, branch
    `feat/p0.4-encrypted-store-log-period`. Set IN PROGRESS. Built `core` drift store +
    repository, `app` encrypted executor + secure key store + Riverpod wiring + home screen;
    17 core tests, 6 widget tests green locally.
  - 2026-08-28 — PR #4 opened. Set IN REVIEW.
  - 2026-08-28 — PR #4 squash-merged to `main`; CI green on `main` (core 23 tests, app 6
    widget tests, debug APK + unsigned iOS build). Set DONE. Manual device install/launch not
    performed — handed off to p0.5.

#### p0.5 — Device smoke: `integration_test` on an emulator/simulator (nightly)
- **Status:** IN REVIEW
- **PR:** https://github.com/Abbo0dio/olf/pull/6
- **Branch / worktree:** `feat/p0.5-device-smoke` in `../olf-wt/p0.5`
- **Owner:** worker: phase0
- **Depends on:** p0.4
- **Requirement refs:** requirements.md §1, §3, §9(1)
- **Goal:** Close the Phase 0 exit-gate caveat — actually *run* the app's on-device
  `integration_test` on a real Android emulator and iOS simulator, and prove the p0.4
  log→relaunch→delete round-trip survives a genuine close-and-reopen of the on-disk SQLCipher
  database. Wired as a **separate, non-blocking nightly workflow** — not a PR gate.
- **Acceptance criteria:**
  - `flutter test integration_test/` passes on an Android emulator in CI, exercising real
    SQLCipher (`sqlcipher_flutter_libs`) + `flutter_secure_storage`.
    - *Status:* **met** on **API 34** — `.github/workflows/nightly-integration.yml` → job
      `android-emulator` (`reactivecircus/android-emulator-runner@v2`, KVM-accelerated x86_64,
      `working-directory: app`, `script: flutter test integration_test/log_period_test.dart`).
      Evidence: run [33178785364](https://github.com/Abbo0dio/olf/actions/runs/33178785364)
      "Android emulator API 34" → pass (test green again on run
      [33180054594](https://github.com/Abbo0dio/olf/actions/runs/33180054594)).
      **API 26** (our documented minimum) was in the matrix but its x86_64 image would not
      boot on GitHub runners — two separate infra failures in two runs (userdata-partition
      sizing; then a corrupt emulator-package download, "Error on ZipFile unknown archive").
      Dropped from the nightly (follow-up PR #7) with a code comment; min-SDK stays enforced
      by the Gradle `minSdk` config and the manual physical-device smoke below.
  - An iOS simulator job on `macos-latest` runs the same suite (or a documented reason it
    can't).
    - *Status:* **met** — `.github/workflows/nightly-integration.yml` → job `ios-simulator`
      boots the newest available iPhone simulator via `xcrun simctl` and runs `flutter test
      integration_test/log_period_test.dart -d <device>`. Evidence: run
      [33178785364](https://github.com/Abbo0dio/olf/actions/runs/33178785364) "iOS simulator"
      → `🎉 1 test passed.` (green again on run 33180054594).
  - The integration test genuinely closes and reopens the DB from disk and leaves state clean.
    - *Status:* `app/integration_test/log_period_test.dart` rewritten to drive two explicit
      `ProviderContainer` launches: launch 1 logs today; the container is disposed and the
      test asserts the first `AppDatabase` is **actually closed** (`SELECT 1` throws); launch 2
      builds a **new** `AppDatabase` instance (`identical(db1, db2)` is false) on the same
      encrypted file, the "Day N" entry is still there, then it's removed so the next nightly
      starts from the empty state.
  - Job wiring keeps `CI OK` semantics coherent.
    - *Status:* the nightly workflow is `schedule:` + `workflow_dispatch` only and is **not**
      in `ci.yml`'s `ci-ok` `needs:` list, so it can never affect a PR's required check.
      `ci.yml` header comment + the `test` job comment now point at it.
- **Manual physical-device smoke (TODO — orchestrator to complete):** one-time install + launch
  on one physical Android and one physical iOS device (log a period, kill the app, relaunch,
  confirm "Day N" persists, delete). Not a blocker for this PR.

  | Device | OS version | Date | Result |
  |---|---|---|---|
  | _(Android)_ | | | |
  | _(iOS)_ | | | |
- **Notes / detail:**
  - **Nightly, not required — rationale.** Emulator/simulator boots take minutes and are
    occasionally flaky; gating every PR on them trades real signal for noise. The p0.4
    restart round-trip is *already* covered headless on every PR by
    `core/test/db/persistence_test.dart` (write → `close()` → reopen → row present → delete)
    and `app/test/widget_test.dart`. The nightly adds the one thing those can't: the real
    SQLCipher native libs + the real platform key store, on a real OS image. A red nightly is
    a bug to chase, not a merge blocker.
  - **No new deps.** `integration_test` (Flutter SDK) was already a dev-dependency from p0.4.
    `sqlite3_flutter_libs` is deliberately **not** added (collides with
    `sqlcipher_flutter_libs` — see p0.4 Gotcha).
  - **API 26 emulator is not run** — its x86_64 image is too unreliable to boot on GitHub's
    runners (see the acceptance note above). The `android-emulator` job also frees ~17 GB of
    unused toolchains (Android NDK, dotnet, GHC, CodeQL) before the emulator step so the AVD's
    ~7 GB userdata partition fits. Both in follow-up PR #7.
  - Resolves p0.4 follow-up (a).
- **Log:**
  - 2026-08-28 — claimed by worker: phase0; worktree `../olf-wt/p0.5`, branch
    `feat/p0.5-device-smoke`. Set IN PROGRESS. Added `.github/workflows/nightly-integration.yml`
    (android-emulator + ios-simulator, nightly + dispatch, non-blocking); rewrote
    `app/integration_test/log_period_test.dart` to prove close-then-reopen; updated `ci.yml`
    comments, CONTRIBUTING.md §5, and §9.
  - 2026-08-28 — PR #6 opened. Set IN REVIEW. Local checks green (format, analyze ×3,
    core 23 tests, app 6 widget tests, dependency audit, YAML parse). Emulator/simulator
    evidence run is blocked until the workflow is on `main` (GitHub `workflow_dispatch`
    rule) — trigger it right after merge.
  - 2026-08-28 — PR #6 merged. First post-merge `workflow_dispatch` run
    ([33178785364](https://github.com/Abbo0dio/olf/actions/runs/33178785364)): **iOS
    simulator ✅** (`🎉 1 test passed`), **Android emulator API 34 ✅**, **API 26 ❌**
    (emulator never booted — runner disk / corrupt emulator-package download). Follow-up
    **PR #7** (`feat/p0.5-emulator-disk-fix`): frees runner disk before the emulator step
    and drops the flaky API 26 leg. Re-run
    ([33180054594](https://github.com/Abbo0dio/olf/actions/runs/33180054594)) confirmed
    iOS + API 34 still green. p0.5 acceptance is functionally met on both platforms;
    the physical-device table remains the only open item.

**Phase 0 exit gate:** CI enforces the worktree→PR→merge workflow (required `CI OK` check);
every PR builds a debug APK (Ubuntu) and an unsigned iOS build (macOS); p0.4 merged and the app
does one real thing (log a period, encrypted, "Day N", delete). p0.5 adds a nightly
`integration_test` run on a real Android emulator + iOS simulator (SQLCipher + key store
exercised for real). **Remaining caveat:** one-time manual install+launch on a physical Android
and physical iOS device is still open (p0.5 table above). Gate considered met for the purpose of
starting Phase 1.

---

### Phase 1 — MVP core tracking (free, un-paywalled)

**Status:** `TODO` · **Goal:** everything in `requirements.md` §1 plus the MUST-HAVE privacy
and inclusivity basics, all free. After this phase the app is a genuinely useful daily tracker.

#### p1.1 — Period logging: start/end, edit, delete, calendar view
- **Status:** TODO
- **Depends on:** p0.4
- **Requirement refs:** §1, §9(1)
- **Goal:** Log a period with start and (optional, later) end date; see periods on a month
  calendar and a history list; edit or delete any past period. Fixing a past period does **not**
  cascade wrong data forward.
- **Acceptance criteria:**
  - Add / edit / delete period from calendar and from history list.
  - Overlapping / impossible ranges are prevented with a clear message.
  - Calendar and history stay in sync after any edit.
- **Tests required:** unit (validation, overlap rules); widget (calendar, editor); integration
  (log → edit → delete round trip).
- **Log:** — created.

#### p1.2 — Flow intensity, spotting, clots — one/two-tap logging
- **Status:** TODO
- **Depends on:** p1.1
- **Requirement refs:** §1, §4 (fast logging), §9(10)
- **Goal:** On any period day, record flow (spotting → light → medium → heavy) and optional
  clot size, in ≤ 2 taps from the home screen.
- **Acceptance criteria:** quick-log sheet reachable in one tap; each further choice is one tap;
  values render on the calendar day cell.
- **Tests required:** widget test asserting tap-count; unit tests for the per-day model.
- **Log:** — created.

#### p1.3 — Cycle derivation & history
- **Status:** TODO
- **Depends on:** p1.1
- **Requirement refs:** §1
- **Goal:** Derive cycles (start-to-start), cycle length, period length; show a history view
  with per-cycle stats and simple variability indicators. No fixed 28-day assumption anywhere.
- **Acceptance criteria:** cycles recompute correctly after any period edit; handles gaps and
  a single logged period gracefully.
- **Tests required:** unit tests over hand-built histories incl. irregular and sparse data.
- **Log:** — created.

#### p1.4 — Prediction v1: next period + fertile window, as ranges, correctable
- **Status:** TODO
- **Depends on:** p1.3
- **Requirement refs:** §1, §2, §4, §9(1) — the headline differentiator
- **Goal:** Predict next period start and the fertile window **from the user's own history**,
  always shown as a **range with a confidence note**, never a single false-precise date.
  When a period is late, the app asks sensitively ("Still no period? Log when it starts") and
  **does not roll the prediction forward silently**. Correcting a prediction (or logging the
  actual date) immediately recomputes.
- **Acceptance criteria:**
  - Predictions display as ranges; copy states uncertainty.
  - Late period → explicit check-in state, not a moving target.
  - Editing history changes the next prediction on the same screen.
  - A minimal on-device model (e.g. robust stats over recent cycles) lives in `core` behind a
    `Predictor` interface so Phase 3 can replace it.
- **Tests required:** unit tests for the predictor over regular + irregular + late-period
  fixtures; widget test for range rendering and the late-period state.
- **Notes / detail:** Full adaptive/irregular-cycle engine + backtesting is **Phase 3**. This
  slice must ship a *correct, humble, correctable* v1, not a stub.
- **Log:** — created.

#### p1.5 — Symptom, mood & discharge logging with custom symptoms
- **Status:** TODO
- **Depends on:** p0.4
- **Requirement refs:** §1, §9(10)
- **Goal:** Log cramps, mood, energy, cervical mucus / discharge, and **user-defined custom
  symptoms**, from a low-friction daily sheet. Nothing buried behind many taps.
- **Acceptance criteria:** add/rename/reorder custom symptoms; multi-select day logging;
  symptoms show on the calendar and in history.
- **Tests required:** unit (custom-symptom CRUD); widget (daily sheet); integration (log across
  several days, verify history).
- **Log:** — created.

#### p1.6 — BBT (manual) & cervical-mucus / fertility-awareness inputs
- **Status:** TODO
- **Depends on:** p1.5
- **Requirement refs:** §1
- **Goal:** Manual basal body temperature entry with a simple chart over the cycle; structured
  cervical-mucus classification (Billings-style). Wearable BBT is Phase 8.
- **Acceptance criteria:** temperature chart per cycle; unit handling (°C/°F); mucus entries
  feed the fertile-window display from p1.4.
- **Tests required:** unit (unit conversion, chart data); widget (chart, entry).
- **Log:** — created.

#### p1.7 — Medication & birth-control entries + one basic reminder
- **Status:** TODO
- **Depends on:** p0.4
- **Requirement refs:** §1, §7
- **Goal:** Record medications and birth-control method (pill/patch/ring/injection). Ship **one**
  simple daily reminder (local notification, no PHI in text). The full granular notification
  system is Phase 4 and will generalise this.
- **Acceptance criteria:** method + schedule stored; a daily reminder fires; reminder text
  contains no health details.
- **Tests required:** unit (schedule model); a test around the notification scheduling wrapper.
- **Log:** — created.

#### p1.8 — Anonymous-by-default, local PIN lock, disclaimers, first-run privacy explainer
- **Status:** TODO
- **Depends on:** p0.4
- **Requirement refs:** §3, §6, §9(8)
- **Goal:** No account required to use anything. Optional numeric PIN to open the app. First-run
  screen plainly explains: data is on your device, HIPAA does not apply here, this is not
  medical advice / not a contraceptive. Biometric unlock, decoy screen, and scheduled deletion
  are **Phase 2**.
- **Acceptance criteria:** fresh install is fully usable with zero personal data entered; PIN
  gate works and is optional; disclaimer copy reviewed against §6.
- **Tests required:** widget/integration for the PIN gate; content test that disclaimer strings
  are present on first run.
- **Log:** — created.

#### p1.9 — Dark mode + gender-neutral, discreet theme baseline
- **Status:** TODO
- **Depends on:** p0.2
- **Requirement refs:** §4, §9(7)
- **Goal:** A neutral, non-pink, non-gendered default theme with full light/dark support and an
  optional pronoun setting used in copy. Sweep all existing strings for "hey girl"-style copy.
- **Acceptance criteria:** every screen to date renders correctly in both themes; a copy
  lint/checklist for gendered language is added and passes.
- **Tests required:** golden tests (light + dark) for main screens; a string-audit test.
- **Log:** — created.

#### p1.10 — Local backup & restore (encrypted export / import)
- **Status:** TODO
- **Depends on:** p1.1–p1.7 (whatever schema exists)
- **Requirement refs:** §4, §9(11)
- **Goal:** Export all data to a single encrypted file the user controls; import it back on the
  same or a new device. This is the data-loss safety net and a store-release prerequisite.
- **Acceptance criteria:** export → wipe → import reproduces all data exactly; format is
  versioned; wrong passphrase fails cleanly.
- **Tests required:** integration (full round trip); unit (serializer versioning).
- **Log:** — created.

#### p1.11 — Explicit pregnancy-loss, birth, and postpartum events (minimal)
- **Status:** TODO
- **Depends on:** p1.3
- **Requirement refs:** §2, §9(3), Prioritized Matrix (MUST-HAVE)
- **Goal:** Let the user log a miscarriage / pregnancy loss, a "gave birth" event, and enter a
  postpartum state, so the cycle engine **stops treating the gap as one long normal cycle**.
  Full pregnancy/TTC/postpartum *modes* are Phase 7 — this is the event + engine handling only.
- **Acceptance criteria:** each event type is loggable with a date; cycle derivation and
  predictions exclude/adjust around it; sensitive, non-clinical copy.
- **Tests required:** unit tests: loss/birth event breaks the cycle chain correctly; prediction
  does not produce nonsense across the event.
- **Log:** — created.

**Phase 1 exit gate:** a new user can log periods/symptoms/BBT/meds, gets correctable range
predictions, can lock the app, can back up and restore, and can log a loss/birth — all offline,
free, in dark mode, with inclusive copy. Retention + a working correction loop are the product
threshold (`requirements.md` Recommendations, Stage 1).

---

### Phase 2 — Privacy & security hardening

**Status:** `TODO` · **Requirement refs:** §3, §6, §7, §8. Slices (agent to expand into rows):

- **p2.1** Biometric unlock (Face ID / Touch ID / Android biometrics) on top of the PIN.
- **p2.2** Decoy / duress screen — an alternate PIN (e.g. `0000`) opens a plausible empty app.
- **p2.3** Scheduled auto-deletion — user sets a retention window; data past it is purged
  (including from any future backups/sync targets).
- **p2.4** Background privacy — blur/mask on app switch; no screenshots of sensitive screens;
  no PHI on the lock screen.
- **p2.5** Standalone **consumer-health privacy policy** screen, linked from first run and
  settings; separate opt-in for collection and (future) sharing; "we never sell data; we
  require valid legal process" commitments (MHMDA / Nevada alignment).
- **p2.6** Transport security baseline for *any* future network use (cert pinning, TLS-only)
  even though nothing calls out yet — so Phase 6/9/10 inherit it.
- **p2.7** In-app privacy education — short, honest explainers (HIPAA gap, law-enforcement
  access, how to delete everything), addressing the "only ~9% take protective action" finding.
- **p2.8** Threat model document + data-flow diagram committed to the repo; reviewed each phase.
- **p2.9** Make the dependency-audit gate strict and documented as a release blocker.

**Exit gate:** lock + decoy + auto-delete + masking shipped and tested; standalone policy live;
threat model committed.

---

### Phase 3 — Correctable adaptive prediction engine v2

**Status:** `TODO` · **Requirement refs:** §2, §4, §9(1)(2), Matrix WOW-FACTOR. Slices:

- **p3.1** Backtesting harness — replay historical data, measure period-start and ovulation-day
  error; synthetic irregular/PCOS/perimenopause/postpartum datasets + opt-in real data.
- **p3.2** Adaptive model — per-user, handles irregular and non-stationary cycles; outputs
  calibrated confidence ranges; degrades gracefully with little data.
- **p3.3** Visible correction loop — when the user fixes a prediction, show that it was
  incorporated and that confidence/behaviour changed ("your correction updated this").
- **p3.4** Anti-snowball guarantees — one bad month cannot poison subsequent months; explicit
  handling of skipped/late/anovulatory cycles.
- **p3.5** Internal accuracy dashboard / metrics (local, private) to track model quality over
  releases. Marketing claims must be substantiable (§6, ASA precedent).
- **p3.6** Swap the `Predictor` implementation from p1.4; keep the interface stable.

**Exit gate:** measurable improvement over v1 on the irregular-cycle datasets; corrections
demonstrably change output; no snowballing in tests.

---

### Phase 4 — Notifications & reminders

**Status:** `TODO` · **Requirement refs:** §7, §9(6). Slices:

- **p4.1** Per-category notification channels: upcoming period, fertile window, medication/BC,
  BBT-logging prompt, late-period check-in, (later) content, (later) subscription. Each
  independently toggleable.
- **p4.2** Behavior-timed delivery — learn when the user usually logs and send then.
- **p4.3** Sensitive copy — late-period check-in worded with care; no "homework collection" tone;
  no PHI in any notification body.
- **p4.4** Quiet hours / do-not-disturb window.
- **p4.5** A permanent, easy "stop asking me to subscribe" control (principle now, enforced in
  Phase 10).
- **p4.6** Generalise the p1.7 medication reminder into this system.

**Exit gate:** every notification type is separately controllable; copy reviewed; quiet hours work.

---

### Phase 5 — Accessibility & design polish

**Status:** `TODO` · **Requirement refs:** §4, §8. Slices:

- **p5.1** WCAG 2.2 AA audit across all screens — screen-reader labels, logical focus order,
  Dynamic Type / text scaling, ≥ 4.5:1 contrast, adequate touch targets, switch/keyboard nav.
- **p5.2** Video/content captions (for Phase 11 content infra — stub the requirement now).
- **p5.3** Accessibility ↔ privacy balance — user control over verbose screen-reader output on
  shared devices; session timeout with warning.
- **p5.4** Discreet app presence — optional alternate app icon and name.
- **p5.5** Low-end performance verification against the §3 budget; fix regressions; add a CI
  size/perf check.
- **p5.6** Data-loss resilience pass — migration tests across simulated OS upgrades.

**Exit gate:** documented AA conformance; perf budget met on reference low-end device.

---

### Phase 6 — Health-platform interop & doctor export

**Status:** `TODO` · **Requirement refs:** §2, §4. Slices:

- **p6.1** Apple Health (HealthKit) read/write: menstrual flow, BBT, sleep, wrist temperature.
- **p6.2** Android Health Connect read/write equivalents; note Google Fit deprecation.
- **p6.3** Import reconciliation — merge external data without creating duplicates or
  overriding user corrections.
- **p6.4** Doctor-ready export — a clean PDF / shareable report of cycle history, symptoms, and
  trends, generated on-device.
- **p6.5** All of the above behind our own interface so the plugin can be swapped.

**Exit gate:** two-way sync with both platforms; a clinician-usable report exports offline.

---

### Phase 7 — Life-stage & condition modes

**Status:** `TODO` · **Requirement refs:** §2, §9(2)(3). Slices (each is its own vertical mode):

- **p7.1** Full pregnancy-loss / birth / postpartum flows building on p1.11 (support resources,
  cycle-return tracking).
- **p7.2** Pregnancy mode — week-by-week development, pregnancy symptom logging.
- **p7.3** TTC (trying to conceive) mode — daily fertility score, timing guidance.
- **p7.4** PCOS mode — symptom-correlation views, irregular-cycle-aware UI.
- **p7.5** Endometriosis mode — pain mapping, flare tracking, correlation with cycle phase.
- **p7.6** PMDD mode — daily symptom rating, luteal-phase correlation, cycle-overlay charts.
- **p7.7** Perimenopause / menopause mode — cycle-variability view, symptom timeline, score.
- **p7.8** Birth-control switching support — guided recalibration when starting/stopping
  hormonal contraception.

Condition-mode *insights* ("your flares track your luteal phase") may later become paid
(Phase 10) but the logging and basic views are free.

**Exit gate:** each mode ships independently, tested, with correlation views where relevant.

---

### Phase 8 — Passive wearable integration

**Status:** `TODO` · **Requirement refs:** §2, §10. Slices:

- **p8.1** Apple Watch companion app (Swift/SwiftUI) — passive overnight wrist-temperature
  capture feeding the Flutter app via HealthKit.
- **p8.2** Oura integration.
- **p8.3** Garmin integration.
- **p8.4** Whoop integration.
- **p8.5** Passive cycle-phase inference from temperature + HRV + sleep, reducing manual logging;
  still fully correctable (Phase 3 engine).
- **p8.6** Graceful multi-source handling (wearable + manual + Health platform) without conflicts.

**Exit gate:** Apple Watch companion + at least one third-party wearable in production; passive
inference measured against the Phase 3 backtester.

---

### Phase 9 — Optional zero-knowledge encrypted sync

**Status:** `TODO` · **Requirement refs:** §3, §10, Matrix WOW-FACTOR. Slices:

- **p9.1** Sync protocol design in `core` — end-to-end / zero-access encryption; server never
  sees plaintext; key derived from a user secret, not stored server-side.
- **p9.2** Account-optional identity (key-based / passphrase), no email required.
- **p9.3** Backend service — minimal, self-hostable if feasible; stores ciphertext blobs only.
- **p9.4** Multi-device sync with conflict resolution that never silently discards a user
  correction.
- **p9.5** Deletion propagation — delete means delete, including backups and any processors
  (MHMDA requirement).
- **p9.6** Local-first remains the **default**; sync is explicitly opt-in with a clear
  explanation of the trade-off.

**Exit gate:** two devices stay in sync through an untrusted server; server compromise exposes
no health data; deletion verified end-to-end.

---

### Phase 10 — Monetization + AI assistant + advanced insights

**Status:** `TODO` · **Requirement refs:** §2, §5, §7, §9(4)(5). Slices:

- **p10.1** Subscription plumbing (StoreKit 2 / Play Billing) — ~$40/yr tier. **Core tracking
  stays free and un-paywalled**; no feature that was ever free moves behind the wall.
- **p10.2** Humane billing UX — one-tap cancellation path, clear renewal reminders, no
  post-action upsell pop-ups, honour the p4.5 "stop asking" control.
- **p10.3** AI health assistant — 24/7 Q&A. Decide the provider (consult `claude-api` skill);
  hard constraint: no health data leaves the device to a third party without zero-knowledge or
  on-device processing. Humane, non-alarming messaging; never an automated "diagnosis".
- **p10.4** Advanced personalized insights (paid) — pattern detection, cycle × sleep ×
  nutrition synthesis, condition-mode correlation insights.
- **p10.5** FSA/HSA eligibility groundwork (receipts, documentation), pending legal review.

**Exit gate:** paid tier live; audit confirms nothing previously free was paywalled; billing
UX reviewed against the §9 complaint list; AI assistant privacy design documented in the threat
model.

---

### Phase 11 — Educational content & privacy-safe community

**Status:** `TODO` · **Requirement refs:** §2. Slices:

- **p11.1** Content system with **named medical reviewers** shown per article; offline-cacheable.
- **p11.2** Content notifications as their own opt-in category (ties to p4.1); never used as
  upsell bait.
- **p11.3** Privacy-safe anonymous community (à la "Secret Chats") — no real identities,
  minimal metadata.
- **p11.4** Moderation tooling and reporting.

**Exit gate:** content is attributed and accessible; community is anonymous, moderated, and
opt-in.

---

### Phase 12 — Scale & defensibility

**Status:** `TODO` · **Requirement refs:** §5, §6. Slices:

- **p12.1** B2B2C channel — employer/insurer benefit packaging, admin/reporting that exposes
  **no individual health data**.
- **p12.2** ISO 27001 readiness track.
- **p12.3** FTC Health Breach Notification Rule process + incident runbook.
- **p12.4** Compliance ledger completed (GDPR, CCPA, MHMDA, Nevada) — see §6.
- **p12.5** **Decision point:** pursue FDA clearance for contraception positioning
  (de novo / 510(k) + prospective clinical study on the scale of Natural Cycles' 15,000+ users)
  or stay explicitly non-medical. Record the decision and rationale in §7 regardless.

**Exit gate:** a documented B2B2C path; compliance ledger complete; FDA decision recorded.

---

### Phase 13 — Desktop app provision (separate & lean)

**Status:** `TODO` · **Goal:** a future desktop app **without adding any weight to mobile**.

- **p13.1** Confirm `core` is fully platform-agnostic (no mobile-only assumptions leaked in).
- **p13.2** Separate desktop shell (Flutter desktop, or Tauri consuming a `core` FFI/bridge —
  decide then) as its **own package / repo target**, not a dependency of `app`.
- **p13.3** Desktop uses the Phase 9 sync (or local import/export) to get data — no new backend.
- **p13.4** Minimal feature set first (view + log + predictions); parity is not a goal.

**Exit gate:** desktop build exists and reuses `core`; mobile install size and dependency
count are unchanged.

---

## 6. Cross-cutting / always-on

These are not phases; they are checked every phase.

### 6.1 Compliance ledger

Maintain a table (fill as work lands): requirement → where addressed → status.

- Non-medical disclaimers present and correct (unless Phase 12 FDA decision changes this).
- MHMDA: standalone consumer-health privacy policy linked from home/first-run; separate opt-in
  for collection and sharing; written authorization before any sale (there is none planned);
  right to deletion incl. backups/processors; no geofencing of health facilities.
- Nevada consumer-health law alignment.
- GDPR (EU) and CCPA (California) data-subject rights.
- FTC Health Breach Notification Rule process.
- No third-party ad/analytics SDKs (enforced by the p0.3 gate).
- Marketing/accuracy claims are substantiated (ASA precedent).
- ISO 27001 track (Phase 12).

### 6.2 Release / store readiness (revisit before each public release)

- App Store / Play data-safety forms match reality (no data collection to declare, ideally).
- Backup/restore (p1.10) shipped before first release.
- Crash reporting, if any, is self-hosted / on-device and PHI-free — or omitted.
- Accessibility statement.
- Support + data-deletion request path.

### 6.3 Engineering hygiene

- `core` stays Flutter-free and platform-agnostic (protects Phase 13).
- Every platform SDK sits behind an interface in `core`.
- Schema changes always ship a migration + a migration test.
- Performance budget (§3) checked in CI.

---

## 7. Decisions Log

Append-only. Newest first. Each entry: date, decision, rationale, who/what decided.

- 2026-08-28 — **Local store realised (p0.4):** `drift` over SQLCipher
  (`sqlcipher_flutter_libs`), key in `flutter_secure_storage`, **Riverpod** for state — all
  three per the §3 provisional table, now committed. Schema + queries + migrations live in
  `core`; the encrypted `QueryExecutor` and key store are injected from `app` so `core` stays
  Flutter/SQLCipher-free (protects Phase 13). drift codegen output is committed and diff-checked
  in CI. — worker: phase0.
- 2026-08-27 — **`CI OK` is a required status check** on the `protect-main` ruleset (p0.3);
  `strict_required_status_checks_policy: false`. A PR now cannot merge unless
  format/analyze/test/dependency-audit/build all pass. — worker: phase0.
- 2026-08-27 — **`pubspec.lock` is committed** for every package (`core` + `app`), overriding
  the usual "libraries don't commit their lock" convention (p0.3). Rationale: the
  dependency-audit gate scans the locked transitive graph statically (no resolution step, no
  drift), and pinned resolutions keep CI reproducible. The audit job still runs `pub get` and
  fails on lock drift so the committed lock cannot go stale. — worker: phase0.
- 2026-08-27 — Monorepo wiring is **plain `path:` dependencies, not Melos** (p0.2). Two
  packages (`core`, `app`); `app` depends on `core` via `path: ../core`. Rationale: two
  packages do not justify Melos's bootstrap step and extra dev-dependency; per-package
  `dart`/`flutter` commands in CI are explicit and readable, and running `core` with plain
  `dart` (no Flutter tooling) actively enforces the "`core` has no Flutter dependency" rule.
  Revisit if the package count grows (e.g. a desktop shell package in Phase 13). — worker: phase0.
- 2026-08-27 — Toolchain pinned via **`mise`** (`mise.toml` at repo root): Flutter **3.35.5**
  / Dart **3.9.2** (p0.1/p0.2). CI pins the same through `FLUTTER_VERSION` in `ci.yml`. This
  confirms the §3 provisional Flutter choice for the MVP; no change to it. — worker: phase0.
- 2026-08-27 — Framework provisionally **Flutter**; architecture is a pure-Dart `core` package
  plus a Flutter `app`, with a future desktop app as a *separate* lean shell reusing `core`.
  Rationale: one codebase for iOS+Android, native-compiled so it runs on low-end devices,
  nothing phones home by default (no-analytics rule), desktop path available without bloating
  mobile. — initial plan author.
- 2026-08-27 — MVP is **fully on-device, no backend**; encrypted sync deferred to Phase 9.
  Rationale: local-first principle, smallest early attack surface. — initial plan author.

---

## 8. Open questions

Move these into the Decisions Log once answered.

- Flutter vs. React Native/Expo — provisionally Flutter; revisit before p0.2 if the team's
  skills point the other way.
- AI assistant provider and on-device vs. zero-knowledge server model (Phase 10).
- Is the desktop shell Flutter-desktop or Tauri+`core` bridge? (Phase 13.)
- Do we ever pursue FDA / contraception positioning? (Phase 12 decision point.)
- Self-host the sync backend vs. managed? (Phase 9.)
- Monetization: confirm ~$40/yr and the exact free/paid line before Phase 10.

---

## 9. Backlog / unscheduled

Ideas and follow-ups not yet placed in a phase. Add freely; groom into phases later.

- ~~**Phase 0 exit-gate: device smoke + `integration_test` in CI.**~~ **Closed → p0.5.**
  `.github/workflows/nightly-integration.yml` runs `flutter test integration_test/` on an
  Android emulator (API 34) and an iOS simulator nightly + on demand — deliberately a
  separate, non-blocking workflow, not a PR gate (emulator boots are slow/flaky; the restart
  round-trip is covered headless on every PR). API 26 was tried and dropped (image won't boot
  reliably on GitHub runners). One-time manual install+launch on a physical Android + iOS
  device remains open — see the p0.5 table in Phase 0.
- **p0.4 follow-ups still open:** move `EncryptedDatabase` open to a background isolate if
  first-frame jank appears; introduce drift schema-snapshot tooling (`drift_dev schema`) with
  the first real migration in Phase 1; revisit the DB directory choice when p1.10
  (backup/export) lands.
- (add more here)

## 10. Orphaned / cut work

Record abandoned branches, superseded designs, and cut features here so history is legible.

- (none yet)
