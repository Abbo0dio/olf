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
| **1** | MVP core tracking — free, un-paywalled | `DONE` | Core tracking usable end-to-end; correction loop works; backup/restore works |
| **2** | Privacy & security hardening | `DONE` | Lock + decoy + auto-delete + masking shipped and tested; standalone policy live; threat model committed; audit gate enforced as a release blocker |
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
- **Status:** DONE
- **PR:** https://github.com/Abbo0dio/olf/pull/6 (merged) + follow-up
  https://github.com/Abbo0dio/olf/pull/7 (merged)
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
      Evidence: runs [33178785364](https://github.com/Abbo0dio/olf/actions/runs/33178785364)
      and [33181230300](https://github.com/Abbo0dio/olf/actions/runs/33181230300)
      "Android emulator API 34" → pass.
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
      → `🎉 1 test passed.` (green again on runs 33180054594 and 33181230300).
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
    and drops the flaky API 26 leg. Final run with those changes
    ([33181230300](https://github.com/Abbo0dio/olf/actions/runs/33181230300)): **fully
    green** — iOS simulator ✅ + Android emulator API 34 ✅, no red jobs. p0.5 acceptance
    is met on both platforms; the physical-device table remains the only open item.
  - 2026-08-28 — PR #7 merged; nightly workflow now on `main`. Confirming
    `workflow_dispatch` run on `main`:
    [33184198626](https://github.com/Abbo0dio/olf/actions/runs/33184198626). Set DONE
    on the strength of runs 33181230300 (iOS + API 34 green) and 33178785364. Only
    open item: the manual physical-device smoke table above — not a Phase 0 blocker,
    automated emulator + simulator coverage is in place.

**Phase 0 exit gate:** CI enforces the worktree→PR→merge workflow (required `CI OK` check);
every PR builds a debug APK (Ubuntu) and an unsigned iOS build (macOS); p0.4 merged and the app
does one real thing (log a period, encrypted, "Day N", delete). p0.5 adds a nightly
`integration_test` run on a real Android emulator + iOS simulator (SQLCipher + key store
exercised for real). **Remaining caveat:** one-time manual install+launch on a physical Android
and physical iOS device is still open (p0.5 table above). Gate considered met for the purpose of
starting Phase 1.

---

### Phase 1 — MVP core tracking (free, un-paywalled)

**Status:** `DONE` (2026-08-30) · **Goal:** everything in `requirements.md` §1 plus the MUST-HAVE privacy
and inclusivity basics, all free. After this phase the app is a genuinely useful daily tracker.

#### p1.1 — Period logging: start/end, edit, delete, calendar view
- **Status:** DONE
- **Branch / worktree:** `feat/p1.1-period-logging` / `../olf-wt/p1.1`
- **Owner:** worker: phase1
- **PR:** [#9](https://github.com/Abbo0dio/olf/pull/9) (merged)
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
- **Notes / detail:**
  - **Schema v1 → v2.** New `periods` table (interval entity), separate from the existing
    `cycle_events` event log:
    | Column | Type | Notes |
    |--------|------|-------|
    | `id` | INTEGER PK AUTOINCREMENT | |
    | `start_date` | INTEGER (unix s) | calendar date, `dateOnly()` on write |
    | `end_date` | INTEGER (unix s), nullable | `null` = ongoing / end not recorded yet |
    | `created_at` | INTEGER (unix s) | |
    | `updated_at` | INTEGER (unix s) | bumped on every edit; lets a correction be told from the original |
    `schemaVersion` bumped to `2`. `migration.onUpgrade` `if (from < 2)` creates `periods` and
    copies every `cycle_events` row of type `periodStart` into it (`start_date` = `date`,
    `end_date` = NULL). Covered by `core/test/db/period_migration_test.dart` (real on-disk
    v1 DB → upgrade → assert shape + row survival).
  - **Why a new table, not a `periodEnd` event type.** A period is an interval; overlap
    checking, editing and deletion are all natural on an interval row and awkward on paired
    start/end events. `cycle_events` stays as the generic point-in-time event log for p1.11
    (loss / birth / postpartum markers). `CycleEventRepository` is retained but the app no
    longer reads it. Recorded in §7.
  - **Validation lives at the repository seam** (`PeriodRepository.addPeriod` / `updatePeriod`
    both call `validatePeriod` and throw `PeriodValidationException`), so the invariant holds
    regardless of which screen calls it. Rules: `endBeforeStart`, `startInFuture`,
    `endInFuture`, `overlapsExisting` (inclusive interval intersection on date-only values; an
    end-less period is treated as open-ended for the check). "Today" is an injected clock so
    the check is deterministic and offline.
  - **No forward cascade.** p1.1 persists nothing derived, so editing one period touches only
    that row — asserted in `drift_period_repository_test.dart` (edit period A; period B's row
    is byte-for-byte unchanged). Cycle/prediction recompute-on-edit is p1.3 / p1.4.
  - **Calendar is a hand-rolled month grid** (`_MonthCalendar`), no `table_calendar` package —
    keeps the dependency-audit surface at zero. Date entry uses Flutter's built-in
    `showDatePicker`.
  - **Sync** is automatic: calendar, history and the header all watch one drift stream
    (`periodsProvider`), so any add / edit / delete refreshes every view.
  - **Follow-ups discovered** (added as TODO rows in §9): period-length sanity ceiling
    (`tooLong`); a one-tap "period ended today" quick action; adopt `drift_dev schema`
    snapshot tooling for the *next* migration.
- **Log:**
  - 2026-08-28 — created.
  - 2026-08-28 — claimed by worker: phase1; worktree `../olf-wt/p1.1`, branch
    `feat/p1.1-period-logging` off `main` @ `3149365`. Building the slice: `periods` table
    (schema v2 + migration + migration test), `PeriodRepository` with validation at the seam,
    hand-rolled month calendar + history list + add/edit/delete editor, full test set.
  - 2026-08-28 — **IN REVIEW**, PR [#9](https://github.com/Abbo0dio/olf/pull/9). Local checks
    green (`mise exec --`): format 0 changed; core + app analyze — no issues; drift codegen no
    diff; core `dart test` 64 passed; app `flutter test` 11 passed; dependency audit PASS (no
    new deps); `pubspec.lock` unchanged. Awaiting orchestrator review + merge.
  - 2026-08-28 — PR #9 squash-merged to `main` (`4d0489f`); CI green on `main`. Set **DONE**.

#### p1.2 — Flow intensity, spotting, clots — one/two-tap logging
- **Status:** DONE
- **PR:** https://github.com/Abbo0dio/olf/pull/10 (merged)
- **Branch / worktree:** `feat/p1.2-flow-intensity` / `../olf-wt/p1.2`
- **Owner:** worker: phase1
- **Depends on:** p1.1
- **Requirement refs:** §1, §4 (fast logging), §9(10)
- **Goal:** On any period day, record flow (spotting → light → medium → heavy) and optional
  clot size, in ≤ 2 taps from the home screen.
- **Acceptance criteria:** quick-log sheet reachable in one tap; each further choice is one tap;
  values render on the calendar day cell.
- **Tests required:** widget test asserting tap-count; unit tests for the per-day model.
- **Notes / detail:**
  - **Schema v2 → v3.** New `daily_flows` table — a per-calendar-day annotation, **not**
    tied to a period row (so editing / deleting a period never cascades onto flow):
    | Column | Type | Notes |
    |--------|------|-------|
    | `date` | INTEGER (unix s), **PK** | calendar date, `dateOnly()` on write — one row per day |
    | `intensity` | TEXT enum `FlowIntensity {spotting,light,medium,heavy}` | |
    | `clot_size` | TEXT enum `ClotSize {small,medium,large}`, nullable | optional |
    | `created_at` / `updated_at` | INTEGER (unix s) | |
    `schemaVersion` → `3`. `onUpgrade` `if (from < 3)` creates `daily_flows` (additive, no
    data move). Migration test `core/test/db/flow_migration_test.dart` (real on-disk v2 → v3).
  - **`DailyFlowRepository`** (`flowOn` / `watchAll` / `setFlow` / `clearFlow`). `setFlow`
    upserts on `date` (preserves `created_at`), injectable clock. No validation rules — any
    intensity is valid, clots optional; the UI only offers the sheet on period days + today.
  - **Interaction change (from p1.1):** tapping a **period day** on the calendar now opens the
    **flow quick-log sheet** (the fast path §4 wants) instead of the period-dates editor. The
    sheet carries an "Edit period dates" button so p1.1's "edit from calendar" still holds.
    Empty-day tap and the "Add a period" button still open the period editor. The home summary
    gains a one-tap "flow" chip for today while a period is ongoing.
  - Quick-log sheet: `ChoiceChip` rows for intensity (4) and clots (4, incl. "None",
    disabled until an intensity is chosen). Each tap persists immediately (upsert) — no Save
    button, so logging flow is exactly 2 taps (open + intensity) and each further choice is 1.
  - Calendar `_DayCell` renders a 4-segment intensity bar + a clot marker, and its semantics
    label gains `", flow <level>"` / `" with <size> clots"`.
- **Log:**
  - 2026-08-28 — created.
  - 2026-08-28 — claimed by worker: phase1; worktree `../olf-wt/p1.2`, branch
    `feat/p1.2-flow-intensity` off `main` @ `4d0489f`. Building: `daily_flows` table (schema
    v3 + migration + test), `DailyFlowRepository`, flow quick-log sheet, calendar cell
    rendering, tap-count widget tests.
  - 2026-08-28 — built. Schema v3 `daily_flows` (per-day, unlinked from `periods`),
    `DriftDailyFlowRepository` (upsert preserving `created_at`), flow quick-log sheet,
    calendar intensity bar + semantics, home summary "Today's flow" chip. v2→v3 migration
    test + v1→v3 pass-through. core 74 / app 14 green, analyze + format clean, dependency
    audit PASS, codegen committed. §7 decision + §9 follow-ups recorded. PR #10 opened into
    `main`; **IN REVIEW** — awaiting orchestrator merge.
  - 2026-08-28 — PR #10 squash-merged to `main` (`76b0f44`); CI green on `main`. Set **DONE**.

#### p1.3 — Cycle derivation & history
- **Status:** DONE
- **PR:** https://github.com/Abbo0dio/olf/pull/12 (merged)
- **Branch / worktree:** `feat/p1.3-cycle-derivation` / `../olf-wt/p1.3`
- **Owner:** worker: phase1
- **Depends on:** p1.1
- **Requirement refs:** §1
- **Goal:** Derive cycles (start-to-start), cycle length, period length; show a history view
  with per-cycle stats and simple variability indicators. No fixed 28-day assumption anywhere.
- **Acceptance criteria:** cycles recompute correctly after any period edit; handles gaps and
  a single logged period gracefully.
- **Tests required:** unit tests over hand-built histories incl. irregular and sparse data.
- **Notes / detail:**
  - **No schema change.** Cycles are *derived* from the `periods` table on every read, never
    stored — consistent with p1.1's "persist nothing derived, no forward cascade". Any period
    add / edit / delete just recomputes; there is no derived row to migrate or invalidate.
  - **`core/lib/src/cycle/`** (pure Dart, no Flutter):
    - **`Cycle`** — one derived cycle: `periodStart`, `periodEnd?`, `nextPeriodStart?` (`null`
      ⇒ current, still-open cycle). Getters: `lengthInDays` = `daysBetween(periodStart,
      nextPeriodStart)` (start-to-start; `null` while current), `periodLengthInDays` =
      inclusive bleed days (`null` while no end recorded), `isCurrent`, `isLikelyGap`
      (`lengthInDays > longestPlausibleCycleDays`, const **45** — a stretch that long is more
      likely a missed entry than a true cycle). Dates normalised via `dateOnly` in the ctor.
    - **`deriveCycles(Iterable<Period>) → List<Cycle>`** — sort by start, pair each period
      with the next; last becomes the current cycle. Newest-first (matches `periodsProvider`).
      Empty in → empty out; one period → one current cycle; input order irrelevant.
    - **`CycleStats.from(Iterable<Cycle>)`** — `completedCycleCount`, `typicalCycleLength`
      (median), `shortestCycleLength` / `longestCycleLength`, `typicalPeriodLength` (median),
      `regularity` (`CycleRegularity { notEnoughData, regular, mostlyRegular, irregular }` by
      max−min spread over the recent ≤ `recentWindow` (12) completed **non-gap** cycles: ≤ 4
      `regular`, ≤ 9 `mostlyRegular`, else `irregular`; < 2 → `notEnoughData`), `hasLikelyGap`.
      Likely-gap cycles are excluded from the length/variability maths but still surfaced via
      the flag. **Every figure is nullable and `null` with no history — no 28-day (or any)
      default.**
  - **`app/lib/src/cycle/`:** `cycle_providers.dart` (`cyclesProvider`, `cycleStatsProvider` —
    plain `Provider`s derived from `periodsProvider.value`; recompute on every period change),
    `cycle_format.dart` (`CycleRegularityLabel.label`, `cycleLengthNote(Cycle)`,
    `summariseStats(CycleStats)` — asks for more logging rather than inventing a number).
  - **`period_calendar_page.dart`:** new `_CycleStatsCard` between the summary and the calendar
    (typical length, min–max range, regularity, a "long gap set aside" note, or the
    "log two periods" nudge — shown once ≥ 1 period exists); each `_History` row subtitle gains
    the derived cycle length via `_HistoryRowDetail`. Heading text, empty-state copy and the
    `Edit period` / `Delete period` tooltips are unchanged, so p1.1 / integration tests still
    pass. a11y: the card is one `Semantics` container labelled with the full summary sentence.
  - **Follow-ups discovered** (added to §9): the regularity thresholds (4 / 9 days) and the
    45-day gap cutoff are heuristics — revisit against real data / p1.4's predictor. History is
    still period-first, not cycle-first; a dedicated per-cycle detail view is later work.
- **Log:**
  - 2026-08-28 — created.
  - 2026-08-28 — claimed by worker: phase1; worktree `../olf-wt/p1.3`, branch
    `feat/p1.3-cycle-derivation` off `main` @ `ae9d4ca`. Building: `core/cycle` derivation +
    stats (no schema change), `cycle` providers/format, cycle-stats card + history subtitle.
  - 2026-08-28 — built. `Cycle` + `deriveCycles` + `CycleStats` (median cycle/period length,
    coarse `CycleRegularity`, `hasLikelyGap`; all figures nullable, no 28-day default).
    `_CycleStatsCard` + per-row cycle length in history; both recompute off `periodsProvider`
    with no stored state. core 93 / app 18 green, analyze + format clean, no codegen diff (no
    schema change), dependency audit PASS, no lock drift. §7 decision + §9 follow-ups recorded.
    PR #12 opened into `main`; **IN REVIEW** — awaiting orchestrator merge.
  - 2026-08-29 — **merged** (PR #12, squash → `dfba13a`). CI green on all 8 checks. Worktree
    + branch cleaned up. **DONE.**

#### p1.4 — Prediction v1: next period + fertile window, as ranges, correctable
- **Status:** DONE
- **PR:** https://github.com/Abbo0dio/olf/pull/13 (merged)
- **Branch / worktree:** `feat/p1.4-prediction-v1` / `../olf-wt/p1.4`
- **Owner:** worker: phase1
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
- **Notes / detail:**
  - **No schema change.** The prediction is *derived* from `cyclesProvider` (itself derived
    from `periods`) on every read — like p1.3, editing history just recomputes.
  - **`core/lib/src/prediction/`** (pure Dart):
    - **`Predictor`** — `CyclePrediction? predict({required List<Cycle> cycles, required
      DateTime today})`. The seam Phase 3's adaptive engine slots into with **no call site
      change**. Returns `null` when history is too thin (0 completed cycles) — the caller shows
      a "keep logging" state, never a fabricated date.
    - **`CyclePrediction`** — `nextPeriod` (`DateRange`), `nextPeriodExpected` (midpoint, only
      shown *with* the range), `fertileWindow` (`DateRange`), `confidence`
      (`PredictionConfidence { low, medium, high }`), `basedOnCycles`, `status`
      (`PredictionStatus { upcoming, dueNow, overdue }`), `daysPastExpected` (int?, overdue
      only).
    - **`DateRange`** — inclusive calendar-day span (`start`, `end`, `lengthInDays`,
      `contains`); the shared "show an uncertain date as a window" type (reused by p1.6).
    - **`RobustPredictor implements Predictor`** — the v1 engine. Anchor on the **last logged
      period start** (`cycles.first.periodStart`); `expected = anchor + typicalCycleLength`
      (median of recent ≤12 non-gap cycles, from `CycleStats`); window
      `[anchor + shortest, anchor + longest]` with a **±1-day floor** (`minPredictionMarginDays`)
      so even a metronomic history is never a single day. Fertile window: `expected − 14`
      (`lutealPhaseDays`, treated as fixed for v1) is estimated ovulation; window is
      `[ovulation − 5, ovulation + 1]` (`fertileDaysBeforeOvulation` / `AfterOvulation`) → a
      7-day span. **Status:** `today < earliest` → upcoming; within window → dueNow; past
      `latest` → overdue with `daysPastExpected = daysBetween(expected, today)`. **The estimate
      never rolls forward** — `expected`/`earliest`/`latest` depend only on the anchor, so a
      late period stays put and the UI shows a check-in. **Confidence:** `high` = regular +
      ≥ 3 cycles; `medium` = regular/mostly-regular + ≥ 2; else `low`; any likely gap forces
      `low`.
    - `date_math.dart` gains `addDays(d, delta)` (DST-safe calendar-day shift).
  - **`app/lib/src/prediction/`:** `prediction_providers.dart` (`predictorProvider` =
    `const RobustPredictor()`; `predictionProvider` — `Provider<CyclePrediction?>` off
    `cyclesProvider` + `DateTime.now()`), `prediction_format.dart` (compact `formatDateRange`,
    `confidenceLabel` / `confidenceNote`, `overdueHeadline` / `overdueBody` — neutral,
    non-alarming, never names a rolled-forward date).
  - **`period_calendar_page.dart`:** `_PredictionCard` between the summary and the cycle-stats
    card, shown only when `predictionProvider` is non-null. Forecast state: "Next period" +
    the range + "most likely <day>" + "Fertile window (estimate)" + the range + a confidence
    note. Overdue state: a distinct "Period check-in" card — "<n> days later than usual",
    reassuring body copy, and a **"Log period start"** button (reuses `_addPeriod`). One
    `Semantics` container with a full-sentence label. Existing screen text unchanged.
  - **Follow-ups discovered** (added to §9): the window uses raw recent min/max, not
    percentiles/MAD — Phase 3; the fertile window is anchored on the point estimate, not
    widened by the next-period uncertainty; the luteal phase is a fixed 14 days (p1.6's
    BBT/mucus inputs can refine it).
- **Log:**
  - 2026-08-28 — created.
  - 2026-08-28 — claimed by worker: phase1; worktree `../olf-wt/p1.4`, branch
    `feat/p1.4-prediction-v1` off `main` @ `dfba13a`. Building: `core/prediction` (`Predictor`
    seam + `CyclePrediction` + `DateRange` + `RobustPredictor`), `prediction` providers/format,
    `_PredictionCard` with forecast + late-period check-in states.
  - 2026-08-28 — built. `RobustPredictor` behind the `Predictor` interface: median recent
    cycle length anchored on the last period start, next-period + fertile windows as
    `DateRange`s with a ±1-day floor, three-bucket confidence, overdue state that never rolls
    forward. `_PredictionCard` (forecast / check-in). core 110 / app 22 green, analyze +
    format clean, no codegen diff (no schema change), dependency audit PASS, no lock drift.
    §7 decision + §9 follow-ups recorded. PR #13 opened into `main`; **IN REVIEW** — awaiting
    orchestrator merge.
  - 2026-08-29 — **merged** (PR #13, squash → `6ab2b33`). CI green on all 8 checks. Worktree
    + branch cleaned up. **DONE.**

#### p1.5 — Symptom, mood & discharge logging with custom symptoms
- **Status:** DONE
- **PR:** https://github.com/Abbo0dio/olf/pull/14 (merged)
- **Branch / worktree:** `feat/p1.5-symptom-logging` / `../olf-wt/p1.5`
- **Owner:** worker: phase1
- **Depends on:** p0.4
- **Requirement refs:** §1, §9(10)
- **Goal:** Log cramps, mood, energy, cervical mucus / discharge, and **user-defined custom
  symptoms**, from a low-friction daily sheet. Nothing buried behind many taps.
- **Acceptance criteria:** add/rename/reorder custom symptoms; multi-select day logging;
  symptoms show on the calendar and in history.
- **Tests required:** unit (custom-symptom CRUD); widget (daily sheet); integration (log across
  several days, verify history).
- **Notes / detail:**
  - **Schema v4** — two new tables in `core/lib/src/db/tables.dart`:
    - **`SymptomTypes`** (`@DataClassName('SymptomType')`) — the symptom *catalogue*: `id`
      (autoIncrement), `name`, `sortOrder` (int, user-controlled ordering), `isBuiltIn` (bool,
      default false), `archivedAt` (nullable — **soft-delete** so historical entries stay
      meaningful and a name is never truly lost), `createdAt` / `updatedAt`
      (`withDefault(currentDateAndTime)`).
    - **`DailySymptomEntries`** (`@DataClassName('DailySymptomEntry')`) — one row per
      (day, symptom) that is present: `date` (DateTimeColumn), `symptomTypeId` (int, FK
      `REFERENCES symptom_types(id) ON DELETE CASCADE`), `createdAt`. Composite PK
      `{date, symptomTypeId}` — toggling is idempotent, multi-select is just several rows.
      Presence-only in v1 (no severity/scale).
    - **Built-ins** (`kBuiltInSymptomNames`, gender-neutral): Cramps, Headache, Chest
      tenderness, Bloating, Fatigue, Nausea, Backache, Low mood, Anxiety, Acne, Discharge.
      Seeded by `_seedBuiltInSymptoms()` called from `onCreate` (after `createAll()`) **and**
      from the `if (from < 4)` upgrade branch, with incrementing `sortOrder` and
      `isBuiltIn: true`.
  - **`core/lib/src/symptom/`** (pure Dart):
    - `symptom_validation.dart` — `SymptomTypeError { empty, tooLong, duplicate }` + `describe()`
      + `SymptomTypeException` + `validateSymptomName(name, {existingActiveNames,
      editingCurrentName})` (trim → empty; > 40 chars → tooLong; case-insensitive clash with
      another active name → duplicate). Mirrors `period_validation.dart`.
    - `symptom_repository.dart` — `abstract interface class SymptomRepository`: `watchTypes()`,
      `activeTypes()`, `addType(name)`, `renameType(id, name)`, `reorderTypes(orderedIds)`,
      `archiveType(id)`, `symptomsOn(date) → Set<int>`, `watchAllEntries()`,
      `setSymptom(date, typeId, {present})`, `clearDay(date)`.
    - `drift_symptom_repository.dart` — `DriftSymptomRepository(this._db, {now})`. Active types
      = `archivedAt IS NULL` ordered by `sortOrder`; validation throws before any write;
      `setSymptom` present → insert-or-ignore, absent → delete row; `reorderTypes` rewrites
      `sortOrder` from list index.
  - **`app/lib/src/symptom/`:** `symptom_providers.dart` (`symptomRepositoryProvider`,
    `symptomTypesProvider` / `symptomEntriesProvider` — plain non-autoDispose `StreamProvider`s,
    same pattern as `flow_providers.dart`), `symptom_format.dart` (`symptomSummary(names)`,
    day-cell fragment), `symptom_day_sheet.dart` (`showSymptomDaySheet(context, {date})` →
    modal bottom sheet; `Wrap` of multi-select `FilterChip`s; each toggle persists immediately;
    "Manage symptoms" → `ManageSymptomsPage`; non-period days also offer "Start a period on this
    day" → `showPeriodEditor(initialStart: date)` to preserve the p1.1 affordance),
    `manage_symptoms_page.dart` (`ReorderableListView` of active types; per-row Rename / Remove
    `IconButton`s; "Add symptom" dialog with inline validation).
  - **`period_calendar_page.dart`:** watch `symptomEntriesProvider` + `symptomTypesProvider` →
    `symptomCountByDay`; `_openForDay` non-period day → `showSymptomDaySheet` (period day
    unchanged — its flow sheet gains an "Add symptoms" button); `_DayCell` gains a
    `symptomCount` indicator + semantic fragment (`'$n symptom(s)'`) — days with none keep the
    exact existing label; new `_RecentSymptoms` section below `_History`.
  - **Tests:** core — `symptom/symptom_validation_test.dart`,
    `symptom/drift_symptom_repository_test.dart`, `db/symptom_migration_test.dart` (v3 → v4),
    update `db/app_database_test.dart` (schemaVersion 4 + two new `onCreate` shape tests) and
    `db/period_migration_test.dart` (→ 4 + `symptom_types` seeded). app —
    `symptom/symptom_day_sheet_test.dart` (multi-select in two taps, persist, reopen, calendar
    indicator), `symptom/manage_symptoms_test.dart` (add / rename / reorder / archive);
    nightly `integration_test/log_symptoms_test.dart` (log across several days → history).
  - **Codegen:** regenerate + commit `core/lib/src/db/app_database.g.dart`.
- **Log:**
  - 2026-08-29 — created.
  - 2026-08-29 — claimed by worker: phase1; worktree `../olf-wt/p1.5`, branch
    `feat/p1.5-symptom-logging` off `main` @ `6ab2b33`. Building: schema v4
    (`symptom_types` + `daily_symptom_entries`, built-ins seeded in the migration),
    `core/symptom` (validation + repository), `symptom` providers/format, low-friction day
    sheet, manage-symptoms screen, calendar + recent-symptoms integration.
  - 2026-08-29 — built. Schema v4: user-editable `symptom_types` catalogue (soft-delete via
    `archived_at`, ~11 gender-neutral built-ins seeded from both `onCreate` and `from < 4`) +
    `daily_symptom_entries` (composite PK `{date, symptom_type_id}`, FK CASCADE, presence-only).
    `DriftSymptomRepository` — validated add/rename, `reorderTypes`, archive, idempotent
    `setSymptom`. App: multi-select day sheet, manage-symptoms `ReorderableListView`, calendar
    day-cell count + dot, "Recent symptoms" section, summary chip; non-period day taps now open
    the symptom sheet (with a "Start a period" shortcut). core 138 / app 30 green, analyze +
    format clean, codegen regenerated + committed, v3→v4 migration test, dependency audit PASS,
    no lock drift. `docs/local-database.md` + §7 decision + §9 follow-ups recorded. PR #14
    opened into `main`; **IN REVIEW** — awaiting orchestrator merge.
  - 2026-08-29 — **merged** (PR #14, squash → `c0ebac2`). CI green. Worktree + branch cleaned
    up. **DONE.**

#### p1.6 — BBT (manual) & cervical-mucus / fertility-awareness inputs
- **Status:** DONE
- **PR:** https://github.com/Abbo0dio/olf/pull/15 (merged)
- **Branch / worktree:** `feat/p1.6-fertility-inputs` / `../olf-wt/p1.6`
- **Owner:** worker: phase1
- **Depends on:** p1.5
- **Requirement refs:** §1
- **Goal:** Manual basal body temperature entry with a simple chart over the cycle; structured
  cervical-mucus classification (Billings-style). Wearable BBT is Phase 8.
- **Acceptance criteria:** temperature chart per cycle; unit handling (°C/°F); mucus entries
  feed the fertile-window display from p1.4.
- **Tests required:** unit (unit conversion, chart data); widget (chart, entry).
- **Notes / detail:**
  - **Schema v5** — three new tables in `core/lib/src/db/tables.dart`, all purely additive
    (`if (from < 5) { createTable × 3 }`), `schemaVersion → 5`:
    - **`BbtEntries`** (`@DataClassName('BbtEntry')`) — one basal temperature per day: `date`
      (DateTimeColumn **PK**), `tempCelsius` (RealColumn — **canonical storage in °C**, all
      conversion is display-only), `createdAt` / `updatedAt`. Upsert on `date`, preserve
      `createdAt` (mirrors `DailyFlows`).
    - **`CervicalMucusEntries`** (`@DataClassName('CervicalMucusEntry')`) — one observation per
      day: `date` (**PK**), `type` (`textEnum<CervicalMucusType>`), `createdAt` / `updatedAt`.
      `enum CervicalMucusType { dry, sticky, creamy, watery, eggWhite }` — Billings-style,
      ordered least → most fertile.
    - **`AppSettings`** (`@DataClassName('AppSetting')`) — tiny key/value prefs store (`key`
      TextColumn **PK**, `value` TextColumn, `updatedAt`). First use: the temperature display
      unit. Reusable by p1.8 / p1.9.
  - **`core/lib/src/bbt/`** (pure Dart):
    - `temperature.dart` — `enum TemperatureUnit { celsius, fahrenheit }` (+ `symbol`),
      `celsiusToFahrenheit` / `fahrenheitToCelsius`, `convertFromCelsius` / `toCelsius`;
      `BbtError { tooLow, tooHigh }` + `validateCelsius` (plausible BBT 34.0–43.0 °C) +
      `describe()` + `BbtException`.
    - `bbt_repository.dart` / `drift_bbt_repository.dart` — `tempOn`, `watchAll`, `setTemp`
      (stores °C), `clearTemp`. Mirrors `DailyFlowRepository`.
    - `bbt_chart.dart` — `BbtChartPoint { cycleDay, date, celsius }` +
      `bbtChartForCycle(Cycle, Iterable<BbtEntry>)` mapping each in-cycle reading to its 1-based
      cycle-day index; points outside the cycle span are dropped.
  - **`core/lib/src/mucus/`** (pure Dart):
    - `cervical_mucus.dart` — `CervicalMucusTypeInfo` extension: `label`, `fertilityRank`
      (0–4), `isFertileQuality` (`creamy` and wetter).
    - `cervical_mucus_repository.dart` / `drift_cervical_mucus_repository.dart` — `mucusOn`,
      `watchAll`, `setMucus`, `clearMucus`.
    - `fertile_window_signal.dart` — **the p1.4 integration.** `observedFertileWindow(
      Iterable<CervicalMucusEntry>, {required DateTime cycleStart, required DateTime today})
      → DateRange?`: over the current cycle's fertile-quality mucus days, returns
      `[firstFertileQualityDay, lastFertileQualityDay + fertileDaysAfterOvulation]`, or `null`
      when there are none. The statistical `RobustPredictor` / `Predictor` seam is **untouched**
      (kept pristine for Phase 3); the observed window is merged in at the display layer.
  - **`core/lib/src/settings/`** — `settings_repository.dart` /
    `drift_settings_repository.dart` (`get(key)`, `set(key, value)`, `watch(key)`), plus a
    `SettingKeys` holder (`temperatureUnit`).
  - **`app/lib/src/bbt/`:** `bbt_providers.dart` (`bbtRepositoryProvider`, `bbtEntriesProvider`,
    `temperatureUnitProvider` — `StreamProvider<TemperatureUnit>` off `settingsRepository.watch`,
    default `celsius`), `bbt_format.dart` (`formatTemp(celsius, unit)`), `bbt_chart_widget.dart`
    (a self-contained `CustomPaint` line chart — **no chart package**, denylist-safe; Y axis in
    the active unit).
  - **`app/lib/src/mucus/`:** `mucus_providers.dart` (`cervicalMucusRepositoryProvider`,
    `cervicalMucusEntriesProvider`, `observedFertileWindowProvider` — `Provider<DateRange?>`
    off `cervicalMucusEntriesProvider` + `cyclesProvider`), `mucus_format.dart`.
  - **`app/lib/src/settings/settings_providers.dart`** — `settingsRepositoryProvider`.
  - **Day sheet** (`symptom_day_sheet.dart`, kept as the one daily log sheet): below the
    symptom chips, a **"Temperature & fluid"** section — a temperature row (shows the reading
    in the active unit, or "Add"; opens a small decimal-`TextField` dialog with a °C/°F toggle
    that also writes the unit pref, validated via `validateCelsius`) and a `Wrap` of
    `ChoiceChip`s for `CervicalMucusType`. Both persist immediately.
  - **`period_calendar_page.dart`:** new `_BbtCard` (shown when the current cycle has ≥ 2 BBT
    points) rendering `bbt_chart_widget`; `_PredictionCard` gains an optional
    `observedFertileWindow` — when present, the fertile-window block adds a "Fertile signs
    (from your notes)" line with that range, and the semantic label mentions it. Existing
    screen text unchanged when there are no mucus observations.
  - **Tests:** core — `bbt/temperature_test.dart`, `bbt/drift_bbt_repository_test.dart`,
    `bbt/bbt_chart_test.dart`, `mucus/cervical_mucus_test.dart`,
    `mucus/drift_cervical_mucus_repository_test.dart`, `mucus/fertile_window_signal_test.dart`,
    `settings/drift_settings_repository_test.dart`, `db/fertility_migration_test.dart` (v4 → v5),
    update `db/app_database_test.dart` (schemaVersion 5 + three new `onCreate` shape tests) and
    the other migration tests (→ 5). app — `bbt/bbt_entry_test.dart` (enter °F → stored °C →
    shown back in °F), `bbt/bbt_chart_test.dart` (chart renders for a seeded cycle),
    `mucus/mucus_entry_test.dart` (pick a type → persists; a fertile-quality pick surfaces in
    the prediction card's observed-window line).
  - **Codegen:** regenerate + commit `core/lib/src/db/app_database.g.dart`.
- **Log:**
  - 2026-08-29 — created.
  - 2026-08-29 — claimed by worker: phase1; worktree `../olf-wt/p1.6`, branch
    `feat/p1.6-fertility-inputs` off `main` @ `c0ebac2`. Building: schema v5 (`bbt_entries`,
    `cervical_mucus_entries`, `app_settings`), `core/bbt` + `core/mucus` + `core/settings`,
    temperature conversion + validation, per-cycle BBT chart, Billings mucus classification
    feeding an observed fertile-window line on the prediction card, day-sheet entry controls.
  - 2026-08-29 — built. Schema v5: `bbt_entries` (°C canonical), `cervical_mucus_entries`
    (Billings enum), `app_settings` key/value. `core/bbt` (°C/°F conversion + plausibility
    validation + `DriftBbtRepository` + `bbtChartForCycle`), `core/mucus`
    (`CervicalMucusTypeInfo` + repo + `observedFertileWindow` — display-layer signal, `Predictor`
    seam untouched), `core/settings` (key/value repo). App: day sheet renamed "Day log" with a
    Temperature & fluid section (°F/°C dialog that also stores the unit pref, single-select
    mucus chips), self-contained `CustomPaint` `_BbtCard` on the home screen, "Fertile signs
    (from your notes)" line on `_PredictionCard`. core 175 / app 36 green, analyze + format
    clean, codegen regenerated + committed, v4→v5 migration test, dependency audit PASS
    (no new deps), no lock drift. `docs/local-database.md` + §7 decision + §9 follow-ups
    recorded. PR #15 opened into `main`; **IN REVIEW** — awaiting orchestrator merge.
  - 2026-08-29 — **merged** (PR #15, squash → `6ac5c5c`). CI green. Worktree + branch
    cleaned up. **DONE.**

#### p1.7 — Medication & birth-control entries + one basic reminder
- **Status:** DONE
- **PR:** https://github.com/Abbo0dio/olf/pull/16 (merged)
- **Branch / worktree:** `feat/p1.7-meds-reminder` / `../olf-wt/p1.7`
- **Owner:** worker: phase1
- **Depends on:** p0.4
- **Requirement refs:** §1, §7
- **Goal:** Record medications and birth-control method (pill/patch/ring/injection). Ship **one**
  simple daily reminder (local notification, no PHI in text). The full granular notification
  system is Phase 4 and will generalise this.
- **Acceptance criteria:** method + schedule stored; a daily reminder fires; reminder text
  contains no health details.
- **Tests required:** unit (schedule model); a test around the notification scheduling wrapper.
- **Notes / detail:**
  - **Schema v6** — three new tables in `core/lib/src/db/tables.dart`, all purely additive
    (`if (from < 6) { createTable × 3 }`), `schemaVersion → 6`:
    - **`Medications`** (`@DataClassName('Medication')`) — the user's medication list: `id`
      (autoIncrement PK), `name` (TextColumn, 1–80 chars), `dosage` (TextColumn nullable, free
      text e.g. "50 mg"), `notes` (TextColumn nullable), `archivedAt` (DateTimeColumn nullable —
      soft delete, mirrors `SymptomTypes`), `createdAt` / `updatedAt`.
    - **`BirthControlEntries`** (`@DataClassName('BirthControlEntry')`) — birth-control method
      history: `id` (autoIncrement PK), `method` (`textEnum<BirthControlMethod>`), `startedOn`
      (DateTimeColumn — date-only), `endedOn` (DateTimeColumn nullable — `null` = current),
      `notes` (TextColumn nullable), `createdAt` / `updatedAt`.
      `enum BirthControlMethod { pill, patch, ring, injection, iud, implant, condom, other }`.
    - **`Reminders`** (`@DataClassName('Reminder')`) — generalisable reminder store (Phase 4
      extends it); p1.7 keeps exactly one row: `id` (autoIncrement PK), `kind`
      (`textEnum<ReminderKind>` — `{ medication }` for now), `hour` (IntColumn 0–23), `minute`
      (IntColumn 0–59), `enabled` (BoolColumn), `createdAt` / `updatedAt`. **No free-text
      column** — the notification body is a fixed generic string, so no health detail can leak.
  - **`core/lib/src/meds/`** (pure Dart):
    - `medication.dart` — `MedicationDraft` + `MedicationError { nameEmpty, nameTooLong }` +
      `describe()` + `MedicationException` + `validateMedication(name)`.
    - `birth_control.dart` — `BirthControlMethod` enum + `BirthControlMethodInfo` extension
      (`label`), `BirthControlDraft`, `BirthControlError { startInFuture, endBeforeStart }` +
      `describe()` + `BirthControlException` + `validateBirthControl({startedOn, endedOn, today})`.
    - `medication_repository.dart` / `drift_medication_repository.dart` — `watchActive`
      (archivedAt IS NULL, ordered by name), `add`, `update`, `archive`, `unarchive`.
    - `birth_control_repository.dart` / `drift_birth_control_repository.dart` — `watchAll`,
      `current` (latest row with `endedOn IS NULL`), `add`, `update`, `end`, `delete`.
  - **`core/lib/src/reminders/`** (pure Dart — **the "schedule model"**):
    - `reminder_schedule.dart` — `enum ReminderKind { medication }`;
      `class ReminderSchedule { final ReminderKind kind; final int hour; final int minute;
      final bool enabled; }` with `ReminderError { hourOutOfRange, minuteOutOfRange }` +
      `describe()` + `ReminderException` + `validateReminderTime(hour, minute)`; and the pure
      function `DateTime nextOccurrence(ReminderSchedule, {required DateTime from})` — the next
      wall-clock `DateTime` at `hour:minute` at or after `from` (today if still ahead, else
      tomorrow). This is the unit-tested schedule model.
    - `reminder_repository.dart` / `drift_reminder_repository.dart` — `watch(kind)` /
      `get(kind)` (the single row or `null`), `save(ReminderSchedule)` (upsert on `kind`).
  - **`app/lib/src/reminders/`:**
    - `reminder_scheduler.dart` — `abstract interface class ReminderScheduler {
      Future<bool> ensurePermission(); Future<void> scheduleDaily(ReminderSchedule);
      Future<void> cancel(ReminderKind); }`. Fixed notification copy lives here as
      `const reminderTitle = 'olf'` / `const reminderBody = 'Time for your daily check-in.'` —
      **no medication name, dosage, method, or the word "medication" appears in either.**
    - `local_notification_reminder_scheduler.dart` — real impl over
      **`flutter_local_notifications`** + **`timezone`** + **`flutter_timezone`** (new deps —
      none denylisted; none are ad/analytics/crash SDKs). Lazy plugin init; `zonedSchedule`
      with `DateTimeComponents.time` for daily repeat; a stable notification id per
      `ReminderKind`. All plugin access is behind this class so `flutter test` never loads a
      platform channel.
    - `reminder_providers.dart` — `reminderSchedulerProvider` (overridable),
      `reminderRepositoryProvider`, `medicationReminderProvider`
      (`StreamProvider<ReminderSchedule?>`), and a `ReminderController` that writes the row and
      calls the scheduler (`scheduleDaily` on enable / time change, `cancel` on disable).
  - **`app/lib/src/meds/`:** `meds_providers.dart` (`medicationRepositoryProvider`,
    `medicationsProvider`, `birthControlRepositoryProvider`, `currentBirthControlProvider`),
    `meds_page.dart` — a **Medications & reminders** screen reached from a new `AppBar`
    action on `HomePage` (`Icons.medication_outlined`, tooltip "Medications & reminders"):
    - "Daily reminder" — `SwitchListTile` (enabled) + a time row opening `showTimePicker`;
      both persist immediately and drive `ReminderController`; enabling first calls
      `ensurePermission()`.
    - "Birth control" — current method (or "None set") + an edit sheet (method
      `DropdownButton` / chips + start-date picker).
    - "Medications" — list of active meds; add / edit / archive via a small form sheet.
  - **Manifest:** `flutter_local_notifications` needs Android `<uses-permission>` entries —
    `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`,
    `VIBRATE` — each with an adjacent `<!-- audited: … Reviewed 2026-08-29 by worker: phase1. -->`
    comment so the dependency-audit CI passes. iOS init requests alert/badge/sound perms.
  - **`app/lib/main.dart`:** `main()` becomes `async` — `WidgetsFlutterBinding.ensureInitialized()`
    then best-effort `LocalNotificationReminderScheduler` init (guarded; failure is non-fatal
    and the app still runs offline).
  - **Tests:** core — `meds/medication_test.dart`, `meds/birth_control_test.dart`,
    `meds/drift_medication_repository_test.dart`,
    `meds/drift_birth_control_repository_test.dart`,
    `reminders/reminder_schedule_test.dart` (**schedule model** — validation +
    `nextOccurrence` across the day boundary / exact-now), `reminders/drift_reminder_repository_test.dart`,
    `db/meds_migration_test.dart` (v5 → v6), update `db/app_database_test.dart`
    (schemaVersion 6 + three `onCreate` shape tests) and the other migration tests (→ 6).
    app — `reminders/reminder_controller_test.dart` (**test around the wrapper**, with a
    `FakeReminderScheduler`: enabling schedules a daily reminder at the chosen time; disabling
    cancels; changing the time reschedules; the scheduled title/body are the fixed generic
    strings and contain no medication/method text), `meds/meds_page_test.dart` (add a
    medication → shows; set a birth-control method → shows; reminder switch state persists).
  - **Codegen:** regenerate + commit `core/lib/src/db/app_database.g.dart`.
- **Log:**
  - 2026-08-29 — created.
  - 2026-08-29 — claimed by worker: phase1; worktree `../olf-wt/p1.7`, branch
    `feat/p1.7-meds-reminder` off `main` @ `6ac5c5c`. Building: schema v6 (`medications`,
    `birth_control_entries`, `reminders`), `core/meds` + `core/reminders` (schedule model +
    `nextOccurrence` + validation + repositories), an `app` `ReminderScheduler` wrapper over
    `flutter_local_notifications` + `timezone` + `flutter_timezone` (new deps) with a fake for
    tests, a Medications & reminders screen, and a fixed no-PHI notification body.
  - 2026-08-29 — built. Schema v6: `medications` (soft-archived list, name-validated),
    `birth_control_entries` (method history, `ended_on IS NULL` = current), `reminders`
    (`UNIQUE (kind)`, one row, no free-text column). `core/meds` (validation + two drift
    repos), `core/reminders` (`ReminderSchedule` + `validateReminderTime` + `nextOccurrence`
    pure model, drift repo). App: `ReminderScheduler` interface + `flutter_local_notifications`
    impl (inexact daily `zonedSchedule`, `timezone` + `flutter_timezone`, all behind the one
    file) + fake; `ReminderController` keeps the row and the OS notification in step; fixed
    generic notification copy (`'olf'` / `'Time for your daily check-in.'`). Medications &
    reminders screen off a home AppBar icon (reminder switch + time, birth-control method
    picker + history, medication add/edit/archive). `main()` now async, best-effort plugin
    init. Android: core-library desugaring in `build.gradle.kts`; two `audited:` manifest
    permissions (`POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`). iOS: `UNUserNotificationCenter`
    delegate line. core 221 / app 44 green, analyze + format clean, codegen regenerated +
    committed (idempotent), v5→v6 migration test, dependency audit PASS (38 rules; new deps
    are not ad/analytics/crash SDKs), no core lock drift. `docs/local-database.md` +
    §7 decision + §9 follow-ups recorded.
  - 2026-08-29 — PR #16 opened into `main`; **IN REVIEW** — awaiting orchestrator merge.
  - 2026-08-29 — **merged** (PR #16, squash → `9a5b292`). CI green (incl. Android APK +
    iOS build). Worktree + branch cleaned up. **DONE.**

#### p1.8 — Anonymous-by-default, local PIN lock, disclaimers, first-run privacy explainer
- **Status:** DONE
- **PR:** https://github.com/Abbo0dio/olf/pull/17 (merged)
- **Branch / worktree:** `feat/p1.8-pin-disclaimers` / `../olf-wt/p1.8`
- **Owner:** worker: phase1
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
- **Notes / detail:**
  - **No schema change.** The one new persisted bit — the `onboarding_complete` flag — reuses
    the p1.6 `app_settings` key/value store (`SettingKeys.onboardingComplete`). The PIN secret
    lives in the platform secure enclave, not the DB.
  - **`core/lib/src/security/`** (pure Dart, new `crypto` direct dep — Dart-team package, not
    ad/analytics):
    - `pin.dart` — `validatePin` (4–12 digits, digits only), `PinError` + `describe()` +
      `PinException`; `PinCredential { saltBase64, hashBase64, iterations }` with a JSON
      `toStorageString` / `fromStorageString` round-trip; `generatePinSalt` (16 random bytes),
      `derivePinCredential` / `hashPin` (iterated HMAC-SHA256, `defaultPinIterations = 30000`),
      `verifyPin` (constant-time compare). **Documented as a UI-level gate, not a crypto
      boundary** — the PIN does not wrap the DB key in Phase 1.
    - `pin_store.dart` — the `PinStore` interface (mirrors `DatabaseKeyStore`); **presence of a
      stored credential is the "lock is on" signal**, no separate flag.
  - **`app/lib/src/security/`:** `secure_storage_pin_store.dart` (`PinStore` over
    `flutter_secure_storage`, same options as `SecureStorageKeyStore`); `pin_providers.dart`
    (`pinStoreProvider`, `pinCredentialProvider` `FutureProvider`, `pinIsSetProvider`,
    `sessionUnlockedProvider` `StateProvider`, and a `PinController` for set / change / clear /
    verify); `pin_unlock_screen.dart` (numeric entry, wrong-PIN message, no lockout yet).
  - **`app/lib/src/onboarding/`:** `disclaimers.dart` (the four disclaimer points as named
    consts — data on this device / no sale, HIPAA doesn't apply, not medical advice, not a
    contraceptive — reviewed against §3 / §6); `onboarding_providers.dart`
    (`firstRunDoneProvider` off `app_settings`); `first_run_screen.dart` (the explainer +
    optional PIN opt-in; "continue" writes the flag and enters the app).
  - **`app/lib/src/app_gate.dart`** — new `MaterialApp.home`. Order: DB opens → first-run
    explainer (once) → PIN lock (if set and session locked) → `HomePage`. A DB error falls
    through to `HomePage` (which owns the fail-safe screen). Re-locks on
    `AppLifecycleState.paused` / `hidden` via `AppLifecycleListener`.
  - **`app/lib/src/settings/settings_page.dart`** — new, reached from a home `AppBar` gear
    icon. For now just an "App lock" switch (set / change / remove the PIN) so the lock is
    genuinely optional and reversible without reinstalling; p1.9 adds theme + pronoun here.
  - **Test harness:** `pumpOlf` gains `onboarded` (default `true` → skips the explainer) and
    `pinStore` (default empty `FakePinStore` → no lock) so every existing widget test is
    unaffected; the new tests opt in.
  - **Tests:** core — `security/pin_test.dart` (validation, hashing determinism + salt/iter
    sensitivity, credential round-trip, verify). app — `onboarding/first_run_test.dart` (every
    disclaimer point shown; continue-with-no-PIN → usable + flag persisted; PIN opt-in stores a
    credential; mismatch rejected), `security/pin_gate_test.dart` (no PIN → no gate; PIN → lock
    screen, wrong rejected, right unlocks), `settings/settings_page_test.dart` (toggle lock on
    → credential stored; off → cleared).
  - **Docs:** `docs/privacy-and-lock.md` (new), `app_settings` key row in
    `docs/local-database.md`.
- **Log:**
  - 2026-08-29 — created.
  - 2026-08-29 — claimed by worker: phase1; worktree `../olf-wt/p1.8`, branch
    `feat/p1.8-pin-disclaimers` off `main` @ `9a5b292`. Building: `core/security` (PIN
    validation + iterated-HMAC hash + `PinStore` interface, `crypto` dep), first-run privacy
    explainer gated on an `app_settings` flag, an `AppGate` root that layers explainer → PIN
    lock → home, an optional PIN (opt-in at first run, toggle in a new Settings screen), and
    re-lock on background. No schema change.
  - 2026-08-29 — built. `core/security/pin.dart` + `pin_store.dart` (UI-level gate,
    documented as *not* a crypto boundary; `crypto` added as a direct dep — not ad/analytics).
    App: `AppGate` (DB → first-run → PIN → home, re-lock on pause), `FirstRunScreen` with the
    four §3/§6 disclaimer points as testable consts + optional PIN opt-in, `PinUnlockScreen`,
    and a new `SettingsPage` (gear icon) with an App-lock switch. `pumpOlf` gained `onboarded`
    / `pinStore` knobs; all pre-existing tests untouched. core 232 / app 52 green, analyze +
    format clean, no schema change / no codegen change, dependency audit PASS (38 rules).
    `docs/privacy-and-lock.md` added; §7 decision + §9 follow-ups recorded.
  - 2026-08-29 — PR #17 opened into `main`; **IN REVIEW** — awaiting orchestrator merge.
  - 2026-08-29 — **merged** (PR #17, squash → `62e4991`). CI green (incl. Android APK + iOS
    build). Worktree + branch cleaned up. **DONE.**

#### p1.9 — Dark mode + gender-neutral, discreet theme baseline
- **Status:** DONE
- **PR:** [#18](https://github.com/Abbo0dio/olf/pull/18) — merged (squash → `fccfc37`)
- **Branch / worktree:** `feat/p1.9-theme-baseline` / `../olf-wt/p1.9`
- **Owner:** worker: phase1
- **Depends on:** p0.2
- **Requirement refs:** §4, §9(7)
- **Goal:** A neutral, non-pink, non-gendered default theme with full light/dark support and an
  optional pronoun setting used in copy. Sweep all existing strings for "hey girl"-style copy.
- **Acceptance criteria:** every screen to date renders correctly in both themes; a copy
  lint/checklist for gendered language is added and passes.
- **Tests required:** golden tests (light + dark) for main screens; a string-audit test.
- **Notes / detail:**
  - **No schema change.** Two new `app_settings` keys via `SettingKeys`: `theme_mode`
    (`system` / `light` / `dark`) and `pronouns` (a `Pronouns` name). Both reuse the p1.6
    key/value store.
  - **`app/lib/src/theme/`:** `olf_theme.dart` — the inline `ThemeData` from `main.dart`
    extracted and hardened into `olfTheme(Brightness)`: the existing neutral sage seed
    (`0xFF4C6B5A` — deliberately not pink/gendered), Material 3, a shared text/`CardTheme`
    baseline so light and dark match. `theme_providers.dart` — `themeModeProvider`
    (`StreamProvider<ThemeMode>` off `settingsRepository.watch(theme_mode)`, `system` until the
    DB is open / the user chooses), plus a setter on the settings repo.
  - **`main.dart`:** `OlfApp` becomes a `ConsumerWidget`, watches `themeModeProvider`, and
    passes `olfTheme(light)` / `olfTheme(dark)` + the chosen `themeMode`.
  - **`core/lib/src/personalization/pronouns.dart`** (pure Dart): `enum Pronouns
    { unspecified, sheHer, theyThem, heHim }`; `PronounForms { subject, object,
    possessiveDeterminer, possessivePronoun, reflexive }`; `formsFor(Pronouns)` —
    `unspecified` resolves to they/them so default copy is correct with nothing set;
    `describePronouns` (`'they / them'` …); `pronounsToStorage` / `fromStorage`;
    `pronounExampleSentence(Pronouns)` — a short sentence built from the forms, the first
    concrete consumer of the setting.
  - **`app/lib/src/settings/settings_page.dart`** (grows): an **Appearance** section — a
    `SegmentedButton` for System / Light / Dark — and a **Pronouns** row (`unspecified` /
    `they/them` / `she/her` / `he/him`) with a live `pronounExampleSentence` preview. Both
    persist immediately.
  - **`app/lib/src/personalization/personalization_providers.dart`:** `pronounsProvider`
    (`StreamProvider<Pronouns>` off `settings`, default `unspecified`).
  - **Inclusive-language sweep:** existing copy is already second-person / neutral (audited —
    no "hey girl" / "ladies" / assumed-partner language). p1.9 **locks that in**:
    `docs/inclusive-language.md` (the checklist) + `app/test/copy/inclusive_language_test.dart`
    — scans every string literal under `app/lib/**` and `core/lib/**` against a denied-phrase
    list and fails on a match.
  - **Tests:** app — `theme/theme_render_test.dart` (each main screen — empty calendar,
    calendar with data, day-log sheet, meds, settings, first-run, PIN unlock — pumps in both
    `olfTheme(light)` and `olfTheme(dark)` with **no exception and no `RenderFlex` overflow**,
    and `Theme.of(context).brightness` matches); `settings/settings_page_test.dart` grows
    (switch theme mode → persisted + `MaterialApp.themeMode` follows; pick pronouns → persisted
    + preview updates); `copy/inclusive_language_test.dart`. core —
    `personalization/pronouns_test.dart` (`formsFor` incl. `unspecified`→they, storage
    round-trip, example sentence per value).
  - **Pixel goldens** (`matchesGoldenFile`) are **deferred** — they need golden CI infra +
    pinned fonts to not be flaky on the ubuntu runner; the render tests above cover the
    acceptance criterion ("renders correctly in both themes"). Noted in §9.
- **Log:**
  - 2026-08-29 — created.
  - 2026-08-29 — claimed by worker: phase1; worktree `../olf-wt/p1.9`, branch
    `feat/p1.9-theme-baseline` off `main` @ `62e4991`. Building: extract + harden the light/dark
    `ThemeData`, a persisted theme-mode override, a `core` `Pronouns` model + optional pronoun
    setting with one live copy use, an inclusive-language checklist + enforcing test, and
    both-theme render tests for every screen. No schema change.
  - 2026-08-29 — built. `core/lib/src/personalization/pronouns.dart` (+ export) with
    `pronouns_test.dart` (7 tests); `app/lib/src/theme/olf_theme.dart` +
    `theme/theme_providers.dart` + `personalization/personalization_providers.dart`; `OlfApp`
    now a `ConsumerWidget` on `themeModeProvider`; `settings_page.dart` grew an **Appearance**
    (`SegmentedButton`) and **Pronouns** (`RadioGroup`) section with a live example-sentence
    preview. Tests: `app/test/theme/theme_render_test.dart` (8 — 4 screens × 2 brightnesses),
    `settings_page_test.dart` +2 (theme-mode persists & `MaterialApp.themeMode` follows;
    pronoun persists & preview updates), `app/test/copy/inclusive_language_test.dart` (source
    scan, passes — existing copy was already clean). Docs: `docs/inclusive-language.md` (new),
    `docs/local-database.md` app_settings row. §7 decision + §9 follow-ups recorded. Full local
    verification batch green; no schema change, no lock drift. Opening PR into `main`.
  - 2026-08-29 — PR [#18](https://github.com/Abbo0dio/olf/pull/18) opened into `main`;
    **IN REVIEW** — awaiting CI + orchestrator merge. Do not self-merge.
  - 2026-08-29 — merged (PR #18, squash → `fccfc37`). **DONE.**

#### p1.10 — Local backup & restore (encrypted export / import)
- **Status:** DONE
- **PR:** [#19](https://github.com/Abbo0dio/olf/pull/19) — merged (squash → `b53e6da`)
- **Branch / worktree:** `feat/p1.10-backup-restore` / `../olf-wt/p1.10`
- **Owner:** worker: phase1
- **Depends on:** p1.1–p1.7 (whatever schema exists)
- **Requirement refs:** §4, §9(11)
- **Goal:** Export all data to a single encrypted file the user controls; import it back on the
  same or a new device. This is the data-loss safety net and a store-release prerequisite.
- **Acceptance criteria:** export → wipe → import reproduces all data exactly; format is
  versioned; wrong passphrase fails cleanly.
- **Tests required:** integration (full round trip); unit (serializer versioning).
- **Notes / detail:**
  - **No schema change.** Backup reads/writes existing tables only.
  - **`core/lib/src/backup/`** (pure Dart):
    - `backup_document.dart` — the versioned, still-plaintext shape:
      `{format: 'olf.backup', formatVersion: 1, appSchemaVersion, createdAt, tables}`.
      `BackupDocument.fromJson` validates and throws `BackupFormatException` on a wrong
      `format`, a missing/non-int version, or a version **newer** than this build; an older
      version falls through to a (currently empty) forward-migration path.
      `backupFormatVersion` is separate from the DB `schemaVersion`, which travels alongside.
    - `backup_service.dart` — `BackupService(AppDatabase)`. `export()` does `SELECT *` per
      table into raw `{column: value}` maps (so integer `DateTime`s and string enum names
      round-trip byte-for-byte); `import(doc)` wipes + re-inserts **every** table in one
      transaction (all-or-nothing), parents before children for the one FK, then
      `notifyUpdates` so open streams rebuild. Refuses a backup whose `appSchemaVersion` ≠
      this build's. A `tableOrder` constant covers the whole schema; a test fails if a new
      table is added without updating it.
    - `backup_cipher.dart` — `BackupCipher.seal/open`. Container: `OLFBK1` magic, 4-byte BE
      header length, JSON header (KDF params + salt + nonce + GCM tag, all public), then
      AES-256-GCM ciphertext of the UTF-8 JSON. Key = PBKDF2-HMAC-SHA256(passphrase, salt),
      210k iterations (stored in the header, so it can rise later). Wrong passphrase →
      `SecretBoxAuthenticationError` → `BackupPassphraseException` (distinct from
      `BackupFormatException`). `validateBackupPassphrase` (≥ 8 chars). Uses the new
      `cryptography` package (pure Dart, no ad/analytics surface) added to `core`.
  - **`app/lib/src/backup/`:**
    - `backup_gateway.dart` — `BackupFileGateway` interface (`writeBackup` / `pickBackup`) +
      `FilePickerBackupFileGateway` using `file_picker` (SAF / `UIDocumentPicker`, **no**
      storage permission). The one platform touch, behind a seam like p1.7's scheduler.
    - `backup_controller.dart` — `BackupController` wires service + cipher + gateway; every
      expected failure (cancel, wrong passphrase, wrong file) is a `RestoreResult` /
      `ExportResult` value, only bugs throw. Suggests `olf-backup-YYYY-MM-DD.olfbackup`.
    - `backup_providers.dart` — `backupControllerProvider` (data-branch only),
      `backupFileGatewayProvider` (overridden in tests).
    - `backup_page.dart` — `BackupPage`: intro copy, "Create an encrypted backup" (passphrase
      + confirm dialog), "Restore from a backup file" (replace-everything warning → file →
      passphrase). Reached from a new **Data** row in Settings. Busy spinner; on restore,
      pops to home.
  - **Tests:** core — `backup_document_test.dart` (versioning: rejects newer, non-int,
    wrong-format, malformed tables/date; round-trips), `backup_cipher_test.dart` (seal/open;
    wrong passphrase + tampered bytes → `BackupPassphraseException`; garbage/truncated →
    `BackupFormatException`; passphrase length), `backup_service_test.dart` (`export` → fresh
    db → `import` reproduces every table exactly; replace-not-merge; schema-version mismatch
    refused; failed insert rolls back; `tableOrder` == schema). app — `backup_controller_test.dart`
    (round trip + all result branches through a fake gateway), `backup_flow_test.dart` (widget:
    Settings → Backup page → export → wipe → restore → data back, pops home; wrong passphrase
    reported).
  - **Deferred:** the real `file_picker` path (SAF dialogs) is exercised only manually /
    on-device, same as p1.7's notification plugin — CI covers the `BackupFileGateway` seam
    with a fake. gzip of the JSON before encryption; a Phase 2 tie-in so scheduled deletion
    also scrubs old backups; deriving the DB key from the same passphrase. See §9.
- **Log:**
  - 2026-08-29 — created.
  - 2026-08-29 — claimed by worker: phase1; worktree `../olf-wt/p1.10`, branch
    `feat/p1.10-backup-restore` off `main` @ `fccfc37`.
  - 2026-08-29 — built. `core/lib/src/backup/` (document + service + cipher) with
    `cryptography` added to `core`; `app/lib/src/backup/` (gateway + controller + providers +
    page); Settings gains a **Data → Backup & restore** row. Tests: core +30
    (`backup_document`/`backup_cipher`/`backup_service`), app +8
    (`backup_controller`/`backup_flow`). No schema change, no new Android permission (SAF).
    `docs/backup-and-restore.md` added; `docs/local-database.md` updated. §7 decision + §9
    follow-ups recorded. Full local verification batch green; app + core `pubspec.lock`
    changed for the new deps (noted in PR). Opening PR into `main`.
  - 2026-08-29 — PR [#19](https://github.com/Abbo0dio/olf/pull/19) opened into `main`;
    **IN REVIEW** — awaiting CI + orchestrator merge. Do not self-merge.
  - 2026-08-29 — merged (PR #19, squash → `b53e6da`). **DONE.**

#### p1.11 — Explicit pregnancy-loss, birth, and postpartum events (minimal)
- **Status:** DONE
- **PR:** [#20](https://github.com/Abbo0dio/olf/pull/20) (merged)
- **Branch / worktree:** `feat/p1.11-loss-birth-events` / `../olf-wt/p1.11`
- **Owner:** worker: phase1
- **Depends on:** p1.3
- **Requirement refs:** §2, §9(3), Prioritized Matrix (MUST-HAVE)
- **Goal:** Let the user log a miscarriage / pregnancy loss, a "gave birth" event, and enter a
  postpartum state, so the cycle engine **stops treating the gap as one long normal cycle**.
  Full pregnancy/TTC/postpartum *modes* are Phase 7 — this is the event + engine handling only.
- **Acceptance criteria:** each event type is loggable with a date; cycle derivation and
  predictions exclude/adjust around it; sensitive, non-clinical copy.
- **Tests required:** unit tests: loss/birth event breaks the cycle chain correctly; prediction
  does not produce nonsense across the event.
- **Notes / detail:**
  - **No schema change.** The dormant `cycle_events` table (kept since v1 for exactly this)
    gets two new `CycleEventType` values — `pregnancyLoss`, `birth` — stored by enum name in
    the existing TEXT column. drift codegen is byte-identical; a v1 database opens as-is.
  - **`core/lib/src/cycle/pregnancy_event.dart`** (pure Dart): `enum PregnancyEndKind
    { loss, birth }` + `.eventType` / `pregnancyEndKindOf` mapping; `class PregnancyEvent`
    (id, kind, date) + `fromRow`; `mostRecentPregnancyEnd`; `enum PregnancyRecoveryState
    { none, awaitingCyclesAfterLoss, postpartum }` + `pregnancyRecoveryState({events,
    periods})` — `none` again as soon as a period starts after the most recent end.
  - **`Cycle`** gains `interruptedBy` (a `PregnancyEndKind?`) + `isPregnancyGap`.
    **`deriveCycles(periods, {pregnancyEvents})`**: an interval a loss / birth falls inside
    (strictly after its start, before the next start) is marked; newest event wins.
    **`CycleStats.from`** uses only cycles *newer than the latest pregnancy gap*
    (`takeWhile(!isPregnancyGap)`), so pre-pregnancy lengths never mix in.
    **`RobustPredictor.predict`** returns `null` while `cycles.first.isPregnancyGap` — no
    forecast projected across the event; it resumes on its own from post-event cycles.
  - **`CycleEventRepository`** gains `logPregnancyEnd` / `watchPregnancyEvents` /
    `pregnancyEvents` (reusing `deleteEvent`); `DriftCycleEventRepository` implements.
  - **app:** `pregnancy/pregnancy_providers.dart` (`cycleEventRepositoryProvider`,
    `pregnancyEventsProvider`, `pregnancyRecoveryStateProvider`,
    `mostRecentPregnancyEndProvider`); `cyclesProvider` now feeds `deriveCycles` the events;
    `pregnancy/pregnancy_events_page.dart` — a dedicated **Settings → Cycle → Pregnancy loss &
    birth** screen (list + add via a kind/date sheet + remove); a gentle `_PregnancyStatusCard`
    on the home body while `PregnancyRecoveryState != none`. Copy is neutral / non-clinical
    ("Pregnancy loss", "Birth"); passes the p1.9 inclusive-language lint.
  - **Tests:** core — `cycle/pregnancy_event_test.dart` (mapping, `mostRecentPregnancyEnd`,
    `pregnancyRecoveryState`); `cycle_derivation_test.dart` +group (gap marking, `CycleStats`
    ignores the far side, no-events = unchanged); `robust_predictor_test.dart` +group (no
    forecast across a birth/loss; resumes on post-event cycles, not the old ones);
    `repository/cycle_event_repository_test.dart` +group. app —
    `pregnancy/pregnancy_events_test.dart` (record → remove), `pregnancy/pregnancy_home_test.dart`
    (birth pauses the forecast + shows the note; note clears after a period).
  - **Deferred:** no in-calendar affordance to log an event on a tapped day (Settings only);
    `PregnancyRecoveryState` flips straight to `none` on the first post-event period rather than
    easing over a few cycles; no pregnancy / TTC / postpartum *modes* (Phase 7); the loss / birth
    day is not drawn on the month calendar. See §9.
- **Log:**
  - 2026-08-29 — created.
  - 2026-08-29 — claimed by worker: phase1; worktree `../olf-wt/p1.11`, branch
    `feat/p1.11-loss-birth-events` off `main` @ `b53e6da`.
  - 2026-08-29 — built. `core/lib/src/cycle/pregnancy_event.dart` + `Cycle.isPregnancyGap` +
    `deriveCycles(pregnancyEvents:)` + `CycleStats` far-side trim + `RobustPredictor` early
    return; `CycleEventRepository` pregnancy-end methods. app: `pregnancy/` providers + page +
    a home status card; Settings **Cycle** section. Tests: core +23, app +3. No schema change
    (codegen unchanged), no lock drift, no new permission. `docs/local-database.md` updated.
    §7 decision + §9 follow-ups recorded. Full local verification batch green. Opening PR.
  - 2026-08-29 — PR [#20](https://github.com/Abbo0dio/olf/pull/20) opened into `main`;
    **IN REVIEW** — awaiting CI + orchestrator merge. Do not self-merge.
  - 2026-08-30 — PR #20 squash-merged to `main`; CI green on `main`. Set **DONE**.

**Phase 1 exit gate:** a new user can log periods/symptoms/BBT/meds, gets correctable range
predictions, can lock the app, can back up and restore, and can log a loss/birth — all offline,
free, in dark mode, with inclusive copy. Retention + a working correction loop are the product
threshold (`requirements.md` Recommendations, Stage 1).

**Exit-gate status — MET (2026-08-30).** All eleven slices p1.1–p1.11 merged to `main`
(PRs #9, #10, #12–#20) with CI green; each slice's acceptance criteria were verified in its PR. The app now covers: period start/end + calendar/history, flow/spotting/clots,
derived cycles + variability, correctable range predictions with an explicit late-period state,
symptoms/mood/discharge + custom symptoms, manual BBT + cervical-mucus, medication/BC + one
reminder, anonymous-by-default + optional PIN + first-run privacy explainer, neutral theme with
dark mode + inclusive copy, encrypted backup/restore, and pregnancy-loss/birth/postpartum
events that break the cycle chain — all on-device and free. Outstanding non-blockers carried
forward: the p0.5 manual physical-device smoke table, and the per-slice §9 follow-ups.

---

### Phase 2 — Privacy & security hardening

**Status:** `DONE` (2026-08-31) · **Requirement refs:** §3, §6, §7, §8.

The Phase 1 slice-list has been expanded into task rows below (p2.1–p2.9). Rows
p2.2–p2.9 carry the intended scope; the agent starting each one fills in the
detail (files, libs, schema, edge cases) in its row as work proceeds, per §1.

**Exit gate:** lock + decoy + auto-delete + masking shipped and tested; standalone policy live;
threat model committed.

#### p2.1 — Biometric unlock on top of the PIN
- **Status:** DONE
- **PR:** [#25](https://github.com/Abbo0dio/olf/pull/25) — merged (squash → `0afdd48`)
- **Branch / worktree:** `feat/p2.1-biometric-unlock` / `../olf-wt/p2.1`
- **Owner:** worker: phase2
- **Depends on:** p1.8
- **Requirement refs:** §3, §7
- **Goal:** Once a PIN is set, the user can opt in to unlocking with Face ID / Touch ID /
  Android biometrics instead of typing it. The PIN always stays available as the fallback;
  biometric unlock is never a lock on its own.
- **Acceptance criteria:**
  - A "Unlock with biometrics" switch appears in Settings → Privacy only when a PIN is set;
    it is disabled with an explanatory subtitle on a device with no enrolled biometric.
  - With it on, the lock screen prompts for biometrics automatically on open and offers a
    "Use biometrics" retry button; a pass unlocks exactly like a correct PIN.
  - A failed / cancelled / unavailable biometric result silently falls back to PIN entry —
    no error nag, no lock-out.
  - No biometric data is read by the app or leaves the device; nothing new is stored
    unencrypted; the OS returns only pass/fail.
- **Tests required:** widget tests for the lock-screen auto-prompt, retry button, and PIN
  fallback; widget tests for the Settings toggle (persists; disabled when incapable); the
  seam is faked so CI never loads the platform channel.
- **Notes / detail:**
  - **No schema change.** One new `app_settings` key — `SettingKeys.biometricUnlock`
    (`'true'` / absent) — reusing the p1.6 key/value store. The PIN credential is untouched.
  - **`core`:** only the `SettingKeys.biometricUnlock` constant (biometric APIs are
    Flutter-only, so nothing else moves into `core`).
  - **`app/lib/src/security/`:** `biometric_gateway.dart` — `BiometricGateway`
    (`canAuthenticate()`, `authenticate({reason})` → `BiometricAuthResult
    { success, failed, unavailable }`); `local_auth_biometric_gateway.dart` — the production
    wrapper over the `local_auth` plugin (added to `app`; Flutter-team package, biometric
    auth only, not on the denylist); `biometric_providers.dart` —
    `biometricGatewayProvider`, `biometricCapableProvider` (`FutureProvider<bool>`),
    `biometricUnlockEnabledProvider` (`StreamProvider<bool>` off `app_settings`),
    `setBiometricUnlockEnabled`. Same seam pattern as `ReminderScheduler` (p1.7) and
    `BackupFileGateway` (p1.10): the app talks to the interface, tests inject
    `FakeBiometricGateway`.
  - `local_auth` is configured `biometricOnly: true` — the *device* passcode is **not**
    accepted for the app PIN. Biometric answers "is it me?"; the app PIN stays the only
    knowledge factor (keeps the model clean for the p2.2 decoy PIN).
  - **`PinUnlockScreen`** grows an auto-prompt (once, on open, guarded on
    enabled && capable) and a "Use biometrics" `TextButton.icon`; a success sets
    `sessionUnlockedProvider` like a correct PIN. **`settings_page.dart`** gains the switch
    under Privacy.
  - **Native config:** Android `MainActivity` now extends `FlutterFragmentActivity` (a
    `local_auth` requirement); `USE_BIOMETRIC` added to the manifest with an `audited:`
    comment (dependency-audit still PASS, 38 rules); iOS `Info.plist` gains
    `NSFaceIDUsageDescription`.
  - **Test harness:** `pumpOlf` gains a `biometricGateway` knob (defaults to an incapable
    `FakeBiometricGateway`, so every pre-p2.1 widget test is unaffected).
  - **Still a UI-level gate** — biometric unlock does not wrap the DB key either; that stays a
    §9 follow-up.
  - **Docs:** `docs/privacy-and-lock.md` (new "Biometric unlock (p2.1)" section),
    `docs/local-database.md` `app_settings` key row.
- **Log:**
  - 2026-08-30 — created; Phase 2 slice-list expanded into rows p2.1–p2.9.
  - 2026-08-30 — claimed by worker: phase2; worktree `../olf-wt/p2.1`, branch
    `feat/p2.1-biometric-unlock` off `main` @ `749f190`. Built: `BiometricGateway` seam +
    `local_auth` wrapper + providers, opt-in `SettingKeys.biometricUnlock`, lock-screen
    auto-prompt + retry button with PIN fallback, Settings switch, `FlutterFragmentActivity`
    + audited `USE_BIOMETRIC` + `NSFaceIDUsageDescription`. No schema change, no codegen
    change. core 281 / app 80 green; analyze `--fatal-infos --fatal-warnings` clean (core +
    app); `dart format` clean; dependency audit PASS (38 rules).
  - 2026-08-30 — PR [#25](https://github.com/Abbo0dio/olf/pull/25) opened into `main`;
    **IN REVIEW** — awaiting CI + orchestrator merge. Do not self-merge.
  - 2026-08-31 — merged (PR #25, squash → `0afdd48`). CI green (incl. Android APK + iOS
    build). Worktree + branch cleaned up. **DONE.**

#### p2.2 — Decoy / duress PIN
- **Status:** DONE
- **PR:** [#26](https://github.com/Abbo0dio/olf/pull/26) — merged (squash `ee69420`)
- **Branch / worktree:** `feat/p2.2-decoy-pin` / `../olf-wt/p2.2`
- **Owner:** worker: phase2
- **Depends on:** p1.8, p2.1
- **Requirement refs:** §3, §7
- **Goal:** A second, user-set PIN that opens a plausible, empty-looking instance of the app
  instead of the real data — for a coerced-unlock situation. Entering it never reveals that a
  decoy exists.
- **Acceptance criteria:**
  - Decoy PIN opens a clean app with its own (throwaway) store; the real data is not reachable
    or detectable from the decoy session.
  - Switching back to the real data requires the real PIN; backgrounding the app ends the
    decoy session.
  - No UI anywhere hints that a decoy is configured while a decoy session is active.
- **Tests required:** unit (PIN routing: real vs decoy vs wrong, precedence, nulls);
  widget (decoy session shows no real data + no "decoy" text; real PIN still works;
  background → real PIN required; decoy PIN can't equal the real PIN).
- **Notes / detail:**
  - **No schema change.** No new dependencies — decoy reuses the existing SQLCipher +
    secure-storage infrastructure.
  - **Two vaults, two keys.** `AppVault { real, decoy }` in
    `app/lib/src/data/vault_database_opener.dart`. Real = `olf.db` under secure-storage key
    `olf.db.key.v1`; decoy = a physically separate `olf-decoy.db` under a **separate** key
    `olf.db.key.decoy.v1`, created lazily on first decoy unlock (same schema + migrations,
    starts empty). `EncryptedDatabase.open` gained an optional `fileName`;
    `SecureStorageKeyStore` / `SecureStoragePinStore` gained a `keyName` param.
  - **`appVaultProvider`** (`StateProvider<AppVault>`, default `real`) drives
    `appDatabaseProvider` through the new `vaultDatabaseOpenerProvider` seam (fake in tests).
    Switching vault closes the previous database and opens the other — only one is ever open.
  - **Routing (`core`):** `routePin(pin, {real, decoy}) → PinRoute { real, decoy, none }` in
    `pin.dart` — real checked first, both `verifyPin` runs, `null` credential never matches.
    `PinController` gained a decoy `PinStore` + `route` / `setDecoyPin` / `clearDecoyPin` /
    `matchesRealPin`. `PinUnlockScreen._submit` flips `appVaultProvider` to `decoy` and
    **awaits the decoy database** before dropping the lock, so the real vault never flashes.
  - **No hint in a decoy session.** `AppGate` skips the first-run explainer when
    `vault == decoy`; Settings hides the "Decoy PIN" setup rows unless `vault == real`, and
    inside a decoy session the ordinary "App lock (PIN)" / "Change PIN" rows operate on the
    *decoy* credential. Preferences (theme, pronouns, biometric flag) naturally come from the
    decoy database.
  - **Setup:** Settings → Privacy → "Decoy PIN" switch (only when a real PIN is set) +
    "Change decoy PIN". A candidate equal to the real PIN is rejected. Turning the real lock
    off also clears the decoy PIN.
  - **Reset on background.** `AppGate`'s `AppLifecycleListener` sets `appVaultProvider` back to
    `real` (and locks) on `paused` / `hidden`. A biometric unlock is always → real.
  - **Test harness:** `pumpOlf` gains `decoyPinStore` (default empty). `FakeVaultOpener` maps
    each vault to a database factory and records what it opened; `driftRuntimeOptions
    .dontWarnAboutMultipleDatabases` is set in the decoy test (the real+decoy pair around a
    switch is intended).
  - **Docs:** `docs/privacy-and-lock.md` ("Decoy / duress PIN (p2.2)" section),
    `docs/local-database.md` (decoy vault note).
- **Log:**
  - 2026-08-30 — created.
  - 2026-08-31 — claimed by worker: phase2; worktree `../olf-wt/p2.2`, branch
    `feat/p2.2-decoy-pin` off `main` @ `0afdd48`. Built: `routePin` (core), `AppVault` +
    `VaultDatabaseOpener` seam, separate decoy database + key, decoy `PinStore` + controller
    methods, lock-screen routing, first-run + Settings hiding in a decoy session, vault reset
    on background. No schema change, no new deps.
  - 2026-08-31 — built. core 287 / app 84 green; analyze `--fatal-infos --fatal-warnings`
    clean (core + app); `dart format` clean; drift codegen unchanged; dependency audit PASS
    (38 rules); no `pubspec.lock` drift; no `app/android/` change. §7 decision + §9 follow-ups
    recorded.
  - 2026-08-31 — PR [#26](https://github.com/Abbo0dio/olf/pull/26) opened into `main`;
    **IN REVIEW** — awaiting CI + orchestrator merge. Do not self-merge.
  - 2026-08-31 — merged as PR #26 (squash `ee69420`). **DONE.**

#### p2.3 — Scheduled auto-deletion (retention window)
- **Status:** DONE
- **PR:** [#27](https://github.com/Abbo0dio/olf/pull/27) — merged (squash `c55bac8`)
- **Branch / worktree:** `feat/p2.3-auto-deletion` / `../olf-wt/p2.3`
- **Owner:** worker: phase2
- **Depends on:** p1.1–p1.11 (whatever data exists), p1.10
- **Requirement refs:** §3, §7, §9(11)
- **Goal:** The user picks a retention window (e.g. "keep 12 months"); anything older is purged
  automatically, and the purge also applies to backups/exports the app produces afterwards.
- **Acceptance criteria:** setting a window purges existing older rows and keeps purging on a
  schedule; "off" is the default and is honoured; a purge is logged (count only, no PHI);
  exports created after a window is set exclude purged data.
- **Tests required:** unit (cutoff maths across all tables, DST-safe); integration (set window
  → old rows gone, recent rows intact, survives restart).
- **Notes / detail:**
  - **No schema change. No new dependencies** — the purge is raw `DELETE`s over the existing
    drift schema.
  - **`RetentionWindow` enum (`core`)** — `off` (default) · `months6` · `year1` · `years2` ·
    `years3`. `cutoff(now)` is built from a fresh **local midnight** via calendar arithmetic
    (`DateTime(now.year, now.month - 6, now.day)` etc.), not a fixed `Duration`, so it is
    DST- and leap-safe and an impossible day (e.g. "31 Feb") normalises forward.
    `storageToken` / `fromStorage` persist the enum name in `app_settings`
    (`SettingKeys.retentionWindow = 'retention_window'`); any unrecognised value → `off`.
  - **`RetentionService` (`core`)** — one `sweep({now, window})` runs a `DELETE` per dated
    table **in a single transaction** and returns a `RetentionSweepResult` (per-table counts
    + cutoff date, **no row content** — safe to log per §3). `deleteWhere` maps each dated
    table to its predicate: plain `date < ?` for `daily_symptom_entries`, `daily_flows`,
    `bbt_entries`, `cervical_mucus_entries`, `cycle_events`; `COALESCE(end_date, start_date)
    < ?` for `periods` (a period straddling the cutoff is **kept**); `ended_on IS NOT NULL
    AND ended_on < ?` for `birth_control_entries` (a still-current method is **always kept**,
    however old). Config tables (`medications`, `symptom_types`, `reminders`, `app_settings`)
    are never touched — a `deleteWhere`-vs-schema partition test fails loudly if a new table
    is added without being classified.
  - **When it runs (`app`):** (1) **on launch** — `retentionStartupSweepProvider`
    (`FutureProvider`) is `ref.watch`ed by `HomePage`, so it fires once the app is past the
    lock / first-run screens; it **guards on `appVaultProvider == AppVault.real`** so a decoy
    session never purges, and no-ops when the window is `off`. (2) **on change** —
    `RetentionController.setWindow` persists the setting then sweeps immediately. (3)
    **before every backup** — `BackupController.export` calls an injected
    `sweepRetention` callback (wired to `RetentionController.sweepNow`) before it snapshots,
    so purged data never lands in a fresh `.olfbackup`.
  - **Logging:** on a non-empty sweep the app `debugPrint`s `retention: purged N entr(y|ies)
    older than YYYY-MM-DD` — a count and a date threshold only, never entry content (§3).
  - **Settings UI:** Privacy → "Auto-delete old entries" `ListTile` showing the current
    window's label; tapping opens a `RadioGroup`/`RadioListTile` picker. Choosing a
    non-`off` window shows a confirmation `AlertDialog` ("permanently deleted now and kept
    out of future backups. This can't be undone.") before it applies; switching to `off`
    applies with no prompt. A `SnackBar` confirms either way. Plain, non-alarming copy;
    gender-neutral; renders in both themes (reuses existing dialog/list components).
  - **§9(11) — reaching already-saved backup files:** **out of scope for this slice, logged
    as a follow-up** (see §9). The app does not track where the user saved past `.olfbackup`
    files (the `BackupFileGateway` hands bytes to an OS save dialog and keeps no path
    registry), so it cannot retroactively open and scrub them. What this slice *does*
    guarantee is that **every backup written from now on** already has the purge applied
    (purge-before-export, above).
- **Decisions (§7):**
  - Calendar-month/-year arithmetic from a fresh local midnight for the cutoff, matching the
    existing `date_math.dart` convention (DST-safe); no fixed `Duration`.
  - Purge = hard `DELETE` (not a soft-delete/tombstone). "Delete means delete" (§9(11)); a
    tombstone would keep the data on disk and complicate backups.
  - Startup sweep lives on `HomePage`, not `AppGate` — it must never run behind the lock or
    in a decoy session, and `HomePage` is the first widget that only mounts on the real,
    unlocked vault.
  - `RetentionService` stays in `core` (operates on the drift schema); the *scheduling* (when
    to sweep) stays in `app` providers.
- **Log:**
  - 2026-08-30 — created.
  - 2026-08-31 — claimed by worker: phase2; worktree `../olf-wt/p2.3`, branch
    `feat/p2.3-auto-deletion` off `main` @ `ee69420`. Built: `RetentionWindow` +
    `RetentionService` (core), retention providers + `RetentionController` (app), startup
    sweep on `HomePage` (real-vault-guarded), purge-before-export hook on `BackupController`,
    Settings picker + confirmation. No schema change, no new deps.
  - 2026-08-31 — built. core 302 / app 92 green; analyze `--fatal-infos --fatal-warnings`
    clean (core + app); `dart format` clean; drift codegen unchanged; dependency audit PASS
    (38 rules); no `pubspec.lock` drift; no `app/android/` change. §7 decision + §9 follow-ups
    recorded (incl. the §9(11) "scrub already-saved backup files" follow-up).
  - 2026-08-31 — PR [#27](https://github.com/Abbo0dio/olf/pull/27) opened into `main`;
    **IN REVIEW** — awaiting CI + orchestrator merge. Do not self-merge.
  - 2026-08-31 — merged as PR #27 (squash `c55bac8`). **DONE.**

#### p2.4 — Background privacy (app-switcher mask, screenshot block, lock-screen hygiene)
- **Status:** DONE
- **PR:** [#28](https://github.com/Abbo0dio/olf/pull/28) — merged (squash `5198074`)
- **Branch / worktree:** `feat/p2.4-background-privacy` / `../olf-wt/p2.4`
- **Owner:** worker: phase2
- **Depends on:** p1.8
- **Requirement refs:** §3, §7
- **Goal:** When the app is backgrounded, the OS app-switcher shows a neutral mask, not the
  last screen; sensitive screens cannot be screenshotted/recorded on Android; no PHI ever
  appears in a notification on the lock screen (already true for p1.7 — lock it in with a
  test).
- **Acceptance criteria:** app-switcher preview is masked on both platforms; `FLAG_SECURE`
  (or equivalent) set on sensitive routes on Android; a test asserts reminder/notification
  text carries no health detail.
- **Tests required:** widget/integration for the mask on lifecycle change; a content test for
  notification text (extends the p1.7 one).
- **Notes / detail:**
  - **No schema change. No new dependencies. No new `<uses-permission>`** — `FLAG_SECURE`
    needs none.
  - **App-switcher mask — `PrivacyShield`** (`app/lib/src/security/privacy_shield.dart`),
    mounted from `MaterialApp.builder` so it sits above every route and dialog. An
    `AppLifecycleListener` flips an opaque, content-free cover (keyed
    `privacyShieldCoverKey`; lock icon + "olf" on `colorScheme.surface`) over the whole app
    **whenever the state is not `resumed`** (`inactive` / `hidden` / `paused`). That covers
    both the task-switcher snapshot and transient interruptions (Control Centre, the
    notification shade). The masked subtree stays mounted, so nav stack / scroll / form
    state survive backgrounding. `Stack(fit: StackFit.expand)` keeps the app's full-screen
    constraints intact.
  - **Screen-capture block — `ScreenSecurity` seam** (`app/lib/src/security/screen_security
    .dart`): `abstract interface ScreenSecurity { Future<void> setSecure(bool); }`. Prod
    impl `MethodChannelScreenSecurity` talks to the `olf/screen_security` `MethodChannel`,
    handled in `MainActivity.kt` (`window.addFlags/clearFlags(FLAG_SECURE)`) —
    keeps the window out of screenshots, screen recordings **and** the Recents thumbnail on
    Android. `PrivacyShield` holds `setSecure(true)` for its whole lifetime (grabbed in
    `initState`, released in `dispose` without touching `ref`). Same fake-in-tests pattern
    as `ReminderScheduler` / `BiometricGateway`; `MissingPluginException` (iOS, desktop,
    tests) is swallowed. `screenSecurityProvider` is overridden in `pumpOlf` so no test
    ever hits the channel.
  - **iOS.** No `FLAG_SECURE` equivalent exists. `AppDelegate.swift` adds a native
    `privacyCover` `UIView` (system-background + SF `lock.fill`) on
    `applicationWillResignActive`, removed on `applicationDidBecomeActive` — the reliable
    app-switcher mask on iOS (the Flutter `PrivacyShield` is the cross-platform secondary).
    No scene manifest in `Info.plist`, so the app-delegate lifecycle hooks fire.
  - **Lock-screen hygiene.** The reminder wording is already fixed generic copy
    (`reminderNotificationTitle` / `Body`, p1.7). p2.4 adds
    `visibility: NotificationVisibility.private` to the Android notification (redacts on a
    secure lock screen) and **broadens** the "no health details" content test to ~25 banned
    terms (period, cycle, ovulation, fertility, flow, BBT, mucus, pregnancy, mood, every
    birth-control method, …).
  - **Not gated on a setting.** The whole app is health data, so the mask and the capture
    block are always on. A per-screen `FLAG_SECURE` scope or a user opt-out is a follow-up
    (see §9).
- **Log:**
  - 2026-08-30 — created.
  - 2026-08-31 — claimed by worker: phase2; worktree `../olf-wt/p2.4`, branch
    `feat/p2.4-background-privacy` off `main` @ `c55bac8`. Built: `PrivacyShield`
    (lifecycle mask, mounted via `MaterialApp.builder`), `ScreenSecurity` seam +
    `olf/screen_security` MethodChannel + `MainActivity.kt` `FLAG_SECURE` handler, iOS
    `AppDelegate` native cover, Android notification `visibility: private`, broadened
    notification-content test. No schema change, no new deps, no new permission.
  - 2026-08-31 — built. core 302 / app 95 green; analyze `--fatal-infos --fatal-warnings`
    clean (core + app); `dart format` clean; dependency audit PASS (38 rules); no
    `pubspec.lock` drift; no `AndroidManifest.xml` change. §9 follow-ups recorded.
  - 2026-08-31 — PR [#28](https://github.com/Abbo0dio/olf/pull/28) opened into `main`;
    **IN REVIEW** — awaiting CI + orchestrator merge. Do not self-merge.
  - 2026-08-31 — merged as PR #28 (squash `5198074`). **DONE.**

#### p2.5 — Standalone consumer-health privacy policy screen
- **Status:** DONE
- **PR:** [#29](https://github.com/Abbo0dio/olf/pull/29) — merged (squash `b24ca49`)
- **Branch / worktree:** `feat/p2.5-privacy-policy` / `../olf-wt/p2.5`
- **Owner:** worker: phase2
- **Depends on:** p1.8
- **Requirement refs:** §3, §6
- **Goal:** A dedicated, plain-language privacy policy screen (not a web link), reachable from
  first run and Settings, with separate opt-ins for any collection and (future) sharing, and
  explicit "we never sell your data / we require valid legal process" commitments aligned to
  MHMDA / Nevada SB370.
- **Acceptance criteria:** screen reachable from both entry points; opt-ins are independent
  and default to off; commitments text reviewed against §3/§6; content is testable strings.
- **Tests required:** content test (each commitment/opt-in present); widget test (navigation
  from first run and Settings; opt-in state persists).
- **Notes / detail:**
  - **No schema change. No new dependencies.** Two new `SettingKeys`
    (`analytics_opt_in`, `data_sharing_opt_in`) in the existing `app_settings` store.
  - **Content — `app/lib/src/privacy/privacy_policy_content.dart`**, named constants like
    `onboarding/disclaimers.dart` so a content test asserts every commitment is on screen and
    the p1.9 copy-lint has one place to look. Eight commitment sections (heading + body):
    *stays on your device* · *we never sell your data* (no "anonymous data set" / "change of
    ownership" exception) · *we do not share it either* (no ad networks / analytics / brokers;
    the dependency-audit gate enforces it) · *if someone asks us for your data* ("we require
    valid legal process", and "nothing for us to hand over" since data never leaves the
    device) · *your consumer-health-data rights* (Washington My Health My Data Act + Nevada
    SB370: no collection/sharing without specific opt-in consent, off by default; access =
    all data is in the app + encrypted export; delete = auto-delete window or uninstall) ·
    *what we would ever collect* (nothing now; any future practice listed here, opt-in) ·
    *children* · *changes to this policy*.
  - **Screen — `PrivacyPolicyScreen`** (`app/lib/src/privacy/privacy_policy_screen.dart`), a
    plain `ConsumerWidget` + `ListView`. Renders the commitments, then a **"Your choices"**
    block with two independent `SwitchListTile`s bound to
    `analyticsOptInProvider` / `dataSharingOptInProvider` (both `StreamProvider<bool>`,
    `false` until the DB is open or the user opts in). `setAnalyticsOptIn` /
    `setDataSharingOptIn` write `'true'` / `'false'`; toggling one never touches the other.
  - **Reachable from both entry points:** a `TextButton` ("Read the full privacy policy")
    under the disclaimer points on `FirstRunScreen`, and a `ListTile` in Settings → Privacy
    (after "Auto-delete old entries"). Both `Navigator.push` the same screen.
  - **Copy** is plain, honest, second person, non-alarming; gender-neutral (the p1.9
    `inclusive_language_test` scans it automatically). Reviewed against §3 (no selling /
    legal-process posture) and §6.
- **Scope boundary with p2.7.** p2.5 is the **policy itself + the two consent switches**.
  The educational explainers — the HIPAA-gap deep-dive, the law-enforcement-access reality,
  and a step-by-step "how to delete everything" walkthrough — are **p2.7** (in-app privacy
  education). p2.5's policy states the rights and where the controls are; p2.7 will add the
  teaching pages that link to them.
- **Log:**
  - 2026-08-30 — created.
  - 2026-08-31 — claimed by worker: phase2; worktree `../olf-wt/p2.5`, branch
    `feat/p2.5-privacy-policy` off `main` @ `5198074`. Built: `privacy_policy_content.dart`
    (8 commitments + choices copy), `PrivacyPolicyScreen`, `analytics_opt_in` /
    `data_sharing_opt_in` keys + providers + setters, first-run link + Settings row. No
    schema change, no new deps.
  - 2026-08-31 — built. core 302 / app 103 green; analyze `--fatal-infos --fatal-warnings`
    clean (core + app); `dart format` clean; drift codegen unchanged; dependency audit PASS
    (38 rules); no `pubspec.lock` drift; no `app/android/` change. §9 follow-ups recorded;
    p2.5/p2.7 boundary noted above.
  - 2026-08-31 — PR [#29](https://github.com/Abbo0dio/olf/pull/29) opened into `main`;
    **IN REVIEW** — awaiting CI + orchestrator merge. Do not self-merge.
  - 2026-08-31 — merged as PR #29 (squash `b24ca49`). **DONE.**

#### p2.6 — Transport security baseline (for any future network use)
- **Status:** DONE
- **PR:** [#30](https://github.com/Abbo0dio/olf/pull/30) — merged (squash `9370943`)
- **Branch / worktree:** `feat/p2.6-transport-security` / `../olf-wt/p2.6`
- **Owner:** worker: phase2
- **Depends on:** none
- **Requirement refs:** §3, §8
- **Goal:** Establish a TLS-only + certificate-pinning HTTP client wrapper and platform ATS /
  network-security-config so that when Phase 6/9/10 first make a network call, they inherit a
  hardened default. Nothing calls out yet.
- **Acceptance criteria:** a shared client refuses cleartext and unpinned TLS; Android
  `network_security_config` and iOS ATS reviewed and documented; a test proves cleartext /
  bad-cert requests fail closed.
- **Tests required:** unit (client rejects http:// and a mismatched pin); doc of the config.
- **Notes / detail:**
  - **No new runtime dependency** (ponytail preference kept — see §9 for the cert-pinning
    package note). **No schema change.** The Dart seam uses `dart:io`'s `HttpClient`.
  - **Android — `app/android/app/src/main/res/xml/network_security_config.xml`**, wired from
    `<application>` with `android:networkSecurityConfig="@xml/network_security_config"` +
    `android:usesCleartextTraffic="false"`. `<base-config cleartextTrafficPermitted="false">`
    with **system trust anchors only** (no `<certificates src="user">`), no
    `<debug-overrides>`. Refuses plain `http://` on every API level. Debug/profile manifests
    are unchanged (they only add `INTERNET` for Flutter tooling; they do not re-enable
    cleartext).
  - **iOS — `app/ios/Runner/Info.plist`**: an explicit strict `NSAppTransportSecurity` dict —
    `NSAllowsArbitraryLoads` / `…InWebContent` / `…ForMedia` / `NSAllowsLocalNetworking` all
    `<false/>`, **no `NSExceptionDomains`**. Makes the OS default explicit and gate-able.
  - **Dart chokepoint — `app/lib/src/net/olf_http_client.dart`**: `OlfHttpClient` is the only
    sanctioned network path. `requireHttpsUrl(url)` throws `ArgumentError` on any non-`https`
    scheme *before a socket opens*; `rejectBadCertificate` is wired to
    `HttpClient.badCertificateCallback` and always returns `false` (fail closed, no feature
    handle to flip it); `certificatePins` (`Map<String, List<String>>`, SPKI-SHA256) is
    **empty today** and `_checkPins` throws for any listed-but-unenforced host so a
    "pinned but unverified" connection can never happen.
  - **Cert-pinning approach (designed, not wired).** When a backend host first exists: add its
    SPKI-SHA256 pins to `certificatePins` **and** a `<domain-config><pin-set>` in the Android
    config (keep them in step), then implement enforcement in `OlfHttpClient` (a
    `SecurityContext` trusting only the pinned chain, or a leaf-SPKI check in a
    `connectionFactory` / post-connect) replacing the `throw` in `_checkPins`. Full write-up
    in `docs/transport-security.md`.
  - **The gate.** `.github/scripts/dependency_audit.dart` gained `--net-config` and `--plist`
    (CI `dependency-audit` job updated). It **fails the build** on
    `usesCleartextTraffic="true"`, `cleartextTrafficPermitted="true"` / missing explicit
    `"false"` / `<debug-overrides>`, and any `NSAllowsArbitraryLoads*` / `NSExceptionDomains`
    in the plist. XML/plist comments are stripped before scanning so a warning comment
    naming a token does not self-trip.
- **Log:**
  - 2026-08-30 — created.
  - 2026-08-31 — claimed by worker: phase2; worktree `../olf-wt/p2.6`, branch
    `feat/p2.6-transport-security` off `main` @ `b24ca49`. Built: Android
    `network_security_config.xml` (+ manifest wiring), explicit strict iOS ATS,
    `OlfHttpClient` seam (`dart:io`, no new dep), dependency-audit `--net-config` /
    `--plist` checks + fixtures, `app/test/net/transport_security_test.dart` (seam unit +
    source-bypass scan). No schema change, no new runtime dependency, no new permission.
  - 2026-08-31 — built. core 306 / app 107 green; analyze `--fatal-infos --fatal-warnings`
    clean (core + app + the audit script); `dart format` clean; drift codegen unchanged;
    dependency audit PASS (incl. the two new transport checks); no `pubspec.lock` drift.
    §9 follow-up recorded (pinning-enforcement + possible package).
  - 2026-08-31 — PR [#30](https://github.com/Abbo0dio/olf/pull/30) opened into `main`;
    **IN REVIEW** — awaiting CI + orchestrator merge. Do not self-merge.
  - 2026-08-31 — merged (squash `9370943`). **DONE.**

#### p2.7 — In-app privacy education explainers
- **Status:** DONE
- **PR:** [#31](https://github.com/Abbo0dio/olf/pull/31) — merged (squash `a7585fe`)
- **Branch / worktree:** `feat/p2.7-privacy-education` / `../olf-wt/p2.7`
- **Owner:** worker: phase2
- **Depends on:** p2.5
- **Requirement refs:** §3, §9(8)
- **Goal:** Short, honest, non-alarming explainers accessible from Settings: the HIPAA gap,
  law-enforcement access reality, and exactly how to delete everything — aimed at the finding
  that only ~9% of users take any protective action.
- **Acceptance criteria:** explainers reachable from Settings; each is a testable string set;
  tone reviewed (no fear-mongering, §4/§9(12)); "delete everything" links to the real action.
- **Tests required:** content test; widget test for navigation + the delete-everything hand-off.
- **Notes / detail:**
  - **No schema change. No new runtime dependency** (ponytail preference kept) — pure Flutter
    widgets + named-constant copy.
  - **Scope boundary with p2.5.** p2.5's `PrivacyPolicyScreen` is the **policy** — the
    plain-language commitments plus the two consent switches. p2.7 is **education**: it
    explains the consumer-health-privacy landscape and gives the concrete delete steps. The
    two are separate screens; p2.7 is linked *from* the policy (and from Settings) but never
    restates it.
  - **Copy — `app/lib/src/privacy/privacy_education_content.dart`** (same named-constant +
    content-test pattern as `privacy_policy_content.dart` / `onboarding/disclaimers.dart`).
    A `PrivacyExplainer` record (`id`, `title`, `summary`, `body` paragraphs) × 3:
    - **`hipaa-gap` — "Why HIPAA doesn't cover olf":** HIPAA binds "covered entities"
      (providers, plans, their contractors), which a self-installed app is not; no federal
      health-privacy law forces a period app to protect entries and some have exploited that;
      olf's privacy does not depend on HIPAA because there is no account and nothing on a
      server; Washington's My Health My Data Act and Nevada SB370 *do* reach apps like this
      and olf is built to meet them (→ policy for specifics).
    - **`law-enforcement` — "If your data were ever requested":** cycle data has been sought,
      including after abortion bans — worth thinking about calmly; from the maker of olf
      essentially nothing could be compelled (no account, no server-side log, no cloud copy —
      a request is answered that valid legal process is required and that no such data is
      held); the real exposure is a seized/borrowed **device**, not a subpoena to a server;
      user-controlled mitigations — PIN + biometric lock, the decoy PIN, the auto-delete
      window. Ends "This is context, not legal advice."
    - **`delete-everything` — "How to delete everything":** everything is one encrypted DB on
      the device, no cloud copy / account. Renders `deleteEverythingSteps` as a **numbered
      list** — (1) optional encrypted export via Backup & restore, (2) set an auto-delete
      window, (3) uninstall removes the encrypted DB + its key, nothing recoverable, decoy
      space goes too. A `FilledButton.tonalIcon` **"Open Backup & restore"** pushes the real
      `BackupPage` — the actionable hand-off that answers the "~9% take a protective action"
      finding.
  - **Screens — `app/lib/src/privacy/privacy_education_screen.dart`:** `PrivacyEducationScreen`
    (index: intro + one `ListTile` per explainer) → `PrivacyExplainerScreen` (body paragraphs;
    for the delete one, the numbered steps + the Backup & restore button). Plain
    `Navigator.push`, `MaterialPageRoute` — no router change, no new provider.
  - **Entry points:** a "Privacy basics" `ListTile` (`Icons.school_outlined`) in
    `settings_page.dart` right under "Privacy policy", and a divider + the same link at the
    bottom of `PrivacyPolicyScreen`.
  - **Tone (§4 / §9(12)):** second person, calm, no fear vocabulary — a content test asserts
    the copy contains none of panic / terrifying / nightmare / disaster / catastroph / doom /
    scary. Gender-neutral — the p1.9 inclusive-language lint scans the new constants
    automatically (the abortion-ban paragraph avoids "women" etc.).
  - **Tests — `app/test/privacy/privacy_education_test.dart`:** content group (exactly three
    explainers, distinct non-empty title/summary/body; per-explainer key-phrase assertions;
    the numbered delete steps end in "uninstall" / "nothing recoverable"; the tone check) +
    widget tests (Settings → "Privacy basics" lists all three; reachable from the policy
    screen; the delete explainer's button lands on the real `BackupPage`; each explainer
    opens with its title + first paragraph). 10 new tests; app suite 116 green.
- **Log:**
  - 2026-08-30 — created.
  - 2026-08-31 — claimed by worker: phase2; worktree `../olf-wt/p2.7`, branch
    `feat/p2.7-privacy-education` off `main` @ `9370943`. Built the three explainers as
    named-constant copy + index/detail screens, wired entry points from Settings and the
    privacy policy screen, delete explainer hands off to `BackupPage`. p2.5/p2.7 boundary
    noted above.
  - 2026-08-31 — built. core 306 / app 116 green; analyze `--fatal-infos --fatal-warnings`
    clean (core + app + the audit script); `dart format` clean; drift codegen unchanged;
    dependency audit PASS; no `pubspec.lock` drift; inclusive-language lint green.
  - 2026-08-31 — PR [#31](https://github.com/Abbo0dio/olf/pull/31) opened into `main`;
    **IN REVIEW** — awaiting CI + orchestrator merge. Do not self-merge.
  - 2026-08-31 — merged (squash `a7585fe`). **DONE.**

#### p2.8 — Threat model + data-flow diagram committed to the repo
- **Status:** DONE
- **PR:** [#32](https://github.com/Abbo0dio/olf/pull/32) — merged (squash `834a4d4`)
- **Branch / worktree:** `feat/p2.8-threat-model` / `../olf-wt/p2.8`
- **Owner:** worker: phase2
- **Depends on:** none
- **Requirement refs:** §3, §7, §8
- **Goal:** A `docs/threat-model.md` (assets, adversaries, trust boundaries, mitigations,
  residual risks) plus a data-flow diagram, established as a living document reviewed at each
  phase gate.
- **Acceptance criteria:** doc covers the current architecture (on-device store, key storage,
  PIN/biometric gate, backup file, no backend); each Phase 0–2 mitigation is cross-referenced;
  a "review log" section is started.
- **Tests required:** n/a (documentation) — but a CI check that the file exists and the review
  log has an entry for the current phase.
- **Notes / detail:**
  - **No schema change. No new runtime dependency. No new permission. No new workflow.**
    Documentation + one pure-Dart guard test in the existing `test` job.
  - **`docs/threat-model.md`** — the living security-design doc. Sections: purpose &
    review cadence; **assets** (cycle/health entries, the SQLCipher key, the PIN/decoy-PIN
    hashes, preferences, `.olfbackup` files, derived predictions); **adversaries** (a person
    with brief physical access to an unlocked phone; a person who can seize the device and
    compel unlock; a co-owner / abuser sharing the device; a thief; malware / another app on
    the device; a network attacker (future); a supply-chain attacker via a dependency; law
    enforcement / civil subpoena; **not** in scope: a nation-state with a device 0-day, a
    hardware forensic lab); **trust boundaries** (the OS keystore ↔ app; the app process ↔
    the encrypted DB file; the app ↔ the OS share sheet / file picker; the app ↔ the
    screen/recents buffer; the app ↔ the network (no traffic today); the repo ↔ its
    dependency graph); **data-flow** as a committed **Mermaid** diagram (renders on GitHub,
    no tooling, no binary) plus a short ASCII fallback, covering: entry → drift → SQLCipher
    file; key create/read via `flutter_secure_storage`; PIN/biometric gate before the DB
    opens; decoy PIN → separate empty vault; retention sweep deleting rows on launch/export;
    export → encrypt → OS save dialog; lifecycle → screen mask; the `OlfHttpClient` seam with
    **no** backend on the other side; **mitigations table** cross-referencing every Phase 0–2
    control to its slice (see below); **residual risks** (pulled from the §9 follow-up
    bullets — key not bound to PIN, no lockout/backoff, iOS screenshot gap, decoy DB left on
    disk when disabled, saved backups not retro-scrubbed, cert-pinning designed-not-wired,
    etc.); and a **`## Review log`** started with a **Phase 2** entry (date, reviewer =
    worker: phase2, what was checked, no changes required).
  - **Mitigation cross-reference (each Phase 0–2 control → slice):** no-account / local-only
    store + SQLCipher at rest → **p0.4**; CI dependency-audit denylist (no ad/analytics SDK)
    + branch protection → **p0.3**; PIN gate + anonymous-by-default + disclaimers + first-run
    explainer → **p1.8**; encrypted backup/restore (`.olfbackup`, AES-GCM, gzip) → **p1.10**;
    discreet dark theme → **p1.9**; biometric unlock over the PIN → **p2.1**; decoy / duress
    PIN → **p2.2**; scheduled auto-deletion (retention window + purge-before-export) →
    **p2.3**; background app-switcher mask + `FLAG_SECURE` + no-PHI recents → **p2.4**;
    standalone consumer-health privacy policy + consent switches → **p2.5**; TLS-only /
    no-cleartext platform config + `OlfHttpClient` chokepoint + transport gate → **p2.6**;
    in-app privacy education (HIPAA gap, law-enforcement reality, delete steps) → **p2.7**;
    this threat model + its guard → **p2.8**.
  - **CI guard — `core/test/threat_model_doc_test.dart`** (pure `dart:io`, picked up by the
    existing `core — unit tests` step in the `test` job — same mechanism as
    `dependency_audit_test.dart` reading real repo files; **no `ci.yml` change**). Asserts:
    (1) `../docs/threat-model.md` exists and is non-trivial; (2) it has the required section
    headings (`## Assets`, `## Adversaries`, `## Trust boundaries`, `## Data flow`,
    `## Mitigations`, `## Review log`); (3) it contains a fenced ```mermaid``` block;
    (4) the `## Review log` section names the **current phase**, where the current phase is
    derived from `../DEVELOPMENT_PLAN.md` as the highest-numbered `### Phase N` whose
    `**Status:**` line is not `TODO`. So when Phase 3 opens the build fails until the review
    log gains a `Phase 3` entry — enforcing the phase-gate review cadence.
  - **Copy:** neutral, non-alarming, gender-neutral; the p1.9 inclusive-language lint already
    scans `app/lib` + `core/lib` string literals, not `docs/`, so the doc's tone is guarded
    by review, not lint (noted as acceptable — it is design documentation, not user copy).
- **Log:**
  - 2026-08-30 — created.
  - 2026-08-31 — claimed by worker: phase2; worktree `../olf-wt/p2.8`, branch
    `feat/p2.8-threat-model` off `main` @ `a7585fe`. Wrote `docs/threat-model.md` (assets /
    adversaries / trust boundaries / Mermaid + ASCII data-flow / mitigation cross-reference
    to every Phase 0–2 slice / residual risks / Review log with a Phase 2 entry) and the
    `core/test/threat_model_doc_test.dart` guard wired via the existing `test` job.
  - 2026-08-31 — merged (squash `834a4d4`). **DONE.**

#### p2.9 — Dependency-audit gate: strict + documented release blocker
- **Status:** DONE
- **PR:** [#33](https://github.com/Abbo0dio/olf/pull/33) — merged (squash `314bba0`)
- **Branch / worktree:** `feat/p2.9-audit-release-blocker` / `../olf-wt/p2.9`
- **Owner:** worker: phase2
- **Depends on:** p0.3
- **Requirement refs:** §3
- **Goal:** Promote the p0.3 dependency-audit from "green by convention" to an explicit,
  documented release blocker: no waivers, failure text points at the process, and the release
  checklist names it.
- **Acceptance criteria:** audit failure is unambiguous and un-waivable in CI; `docs/
  dependency-audit.md` states it is a release blocker with the escalation path; a release
  checklist doc references it.
- **Tests required:** extend `core/test/dependency_audit_test.dart` for any new rule classes;
  doc review.
- **Notes / detail:**
  - **No schema change. No new runtime dependency. No new permission. No new workflow**
    (ci.yml hardened in place). This is the **last Phase 2 build slice** — the phase-close
    doc bump comes after.
  - **Un-waivable in CI — the three soft-pass surfaces closed:**
    1. **A skipped audit now fails the board.** `ci-ok` (the required `CI OK` check) already
       failed on a job `result` of `failure` / `cancelled`; it now *also* fails unless the
       `dependency-audit` job `result` is exactly `success`. Previously, removing the Flutter
       workspace (or the job's `if:` guard) would let the audit **skip** while `CI OK` stayed
       green — that path is gone. Uses `jq '."dependency-audit".result'` on `toJSON(needs)`.
    2. **The CI arguments are locked.** A new test in `dependency_audit_test.dart` reads
       `.github/workflows/ci.yml` and asserts the audit still runs with all five inputs
       (`--denylist`, both `--lock`s, `--manifest`, `--net-config`, `--plist`), the
       stale-lock `git diff --exit-code` guard is still present, no job carries
       `continue-on-error`, and `ci-ok` still `needs:` + hard-checks `dependency-audit`.
       Quietly dropping `--lock app/pubspec.lock` (etc.) now fails the `test` job.
    3. **No script bypass.** Tests assert the script has **no** `--skip` / `--force` /
       `--allow` / `--allowlist` / `--no-fail` / `--waive` option and that **no environment
       variable** (`SKIP_DEPENDENCY_AUDIT`, `OLF_SKIP_AUDIT`, `NO_AUDIT`, …) suppresses a
       violation — it still exits 1.
  - **Failure output points at the process** (`.github/scripts/dependency_audit.dart`). After
    the violation list the script now prints: this is a RELEASE BLOCKER (p2.9), it cannot be
    waived / skipped / overridden, there is no flag / env var / allowlist, then the concrete
    steps — find who pulls the package in (`dart pub deps -s list` / `flutter pub deps -s
    list`), **remove/replace it** as the default fix; a genuine false positive from an
    over-broad `~`/`re:` rule is handled by the **security reviewer narrowing that rule** in
    the same PR with recorded sign-off (never a carve-out, never removing a rule to go
    green); removing an entry needs sign-off. Links `docs/dependency-audit.md` +
    `docs/release-checklist.md`. The exit-2 "bad invocation" path also now states plainly
    that the gate did not run and that this is still a failure.
  - **`docs/dependency-audit.md`** gains a **"Release blocker (p2.9)"** section: the
    un-waivable properties spelled out (no flag, no env var, no `continue-on-error`, a skip
    counts as a failure, the CI args are test-locked) and the **escalation path** — who
    decides (the security-reviewer role; for a solo maintainer, an explicit written
    self-review in the PR), and the two legitimate outcomes (remove the dependency; or
    narrow a false-positive rule with sign-off). Local-run snippet updated to the full
    five-flag invocation; exit-code note says any non-zero (incl. exit 2) fails CI.
  - **`docs/release-checklist.md`** (new, deliberately short — ponytail): a pre-release
    checklist with **BLOCKER** line items — `CI OK` green, **dependency audit ran and
    passed** (linking the escalation path), no unreviewed runtime dependency, threat-model
    Review log current for the phase — plus lighter checks (version bump, changelog,
    migration test, size report) and a "who signs off" note.
  - **`core/test/dependency_audit_test.dart`** — the `run` helper gained an `environment:`
    parameter; +4 tests in a `release blocker (p2.9)` group (failure-text content, env-var
    no-op, no bypass flag in the script source, CI wiring lock), and the exit-2 test now
    also asserts the "gate did not run" message. 315 core tests pass (was 311).
- **Log:**
  - 2026-08-30 — created.
  - 2026-08-31 — claimed by worker: phase2; worktree `../olf-wt/p2.9`, branch
    `feat/p2.9-audit-release-blocker` off `main` @ `834a4d4`. Hardened `ci-ok` to require a
    `success` (not `skipped`) audit result; expanded the script's failure epilogue with the
    un-waivable statement + escalation steps; added the "Release blocker (p2.9)" section to
    `docs/dependency-audit.md`; created `docs/release-checklist.md`; extended
    `dependency_audit_test.dart` with the wiring-lock / no-bypass / failure-text tests.
  - 2026-08-31 — built. core 315 / app 116 green; analyze `--fatal-infos --fatal-warnings`
    clean (core + app + the audit script); `dart format` clean (core + app + `.github/
    scripts`); drift codegen unchanged; the real-tree audit run PASSes; no `pubspec.lock`
    drift. No schema change, no new runtime dependency, no new workflow.
  - 2026-08-31 — merged (squash `314bba0`, PR #33). **DONE.**

**Phase 2 exit gate:** the MUST-HAVE privacy/security controls from `requirements.md` §3
(and §6/§7/§8) are shipped, tested, and enforced: PIN + biometric lock, decoy/duress PIN,
scheduled auto-deletion, background masking, a standalone consumer-health privacy policy,
a TLS-only transport baseline, in-app privacy education, a committed threat model, and an
un-waivable dependency-audit release blocker.

**Exit-gate status — MET (2026-08-31).** All nine slices p2.1–p2.9 merged to `main`
(PRs #25–#33) with CI green; each slice's acceptance criteria were verified in its PR.

- **Lock + decoy + auto-delete + masking shipped and tested:** biometric unlock over the
  PIN (**p2.1**, PR #25 `0afdd48`); decoy/duress PIN routing to a separate empty vault
  (**p2.2**, PR #26 `ee69420`); retention window with purge-before-export (**p2.3**, PR #27
  `c55bac8`); app-switcher mask + `FLAG_SECURE` + no-PHI recents (**p2.4**, PR #28
  `5198074`). Each carries unit + widget/seam tests headless in CI.
- **Standalone policy live:** in-app `PrivacyPolicyScreen` with the commitments + two
  default-off consent switches, reachable from first-run and Settings, MHMDA/SB370-aligned
  (**p2.5**, PR #29 `b24ca49`), plus the honest, non-alarming in-app explainers — HIPAA
  gap, law-enforcement reality, how to delete everything (**p2.7**, PR #31 `a7585fe`).
- **Threat model committed:** `docs/threat-model.md` (assets / adversaries / trust
  boundaries / data-flow diagram / mitigation cross-reference to every Phase 0–2 slice /
  residual risks / phase-gate Review log) with a CI guard (**p2.8**, PR #32 `834a4d4`).
- **Supporting hardening:** TLS-only Android/iOS config + `OlfHttpClient` chokepoint +
  transport gate (**p2.6**, PR #30 `9370943`); the dependency-audit promoted to an
  explicit, un-waivable release blocker with a documented escalation path and a
  `docs/release-checklist.md` (**p2.9**, PR #33 `314bba0`).

Outstanding non-blockers carried forward: the per-slice §9 follow-ups (key-to-PIN binding,
failed-attempt lockout/backoff, iOS screenshot gap, decoy-DB cleanup on disable, retro-scrub
of saved backups, cert-pinning enforcement, native-dep audit coverage), and the p0.5 manual
physical-device smoke table.

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

- 2026-08-31 — **p2.2 decoy PIN routes to a physically separate, separately-keyed database;
  no schema change, no new deps.** Rationale: (1) **Two vaults, not a filtered view.** A decoy
  session must be unable to *reach or detect* the real data even by a determined coerced user,
  so the decoy is its own `olf-decoy.db` under its own secure-storage key
  (`olf.db.key.decoy.v1`), created lazily on first decoy unlock. `AppVault { real, decoy }`
  selects the (file, key) pair via a new `VaultDatabaseOpener` seam; `appDatabaseProvider`
  watches `appVaultProvider` and keeps exactly one database open — switching closes the other.
  "Its own throwaway store" is then true by construction. (2) **Routing is pure and in `core`.**
  `routePin(pin, {real, decoy}) → PinRoute` (real first, both `verifyPin` run, `null` never
  matches) is unit-tested independently; `PinUnlockScreen._submit` flips the vault and *awaits
  the decoy database* before dropping the lock so the real vault never flashes. (3)
  **Non-detectability is UI-level, per-session.** `AppGate` skips first-run when `vault ==
  decoy`; Settings hides the "Decoy PIN" rows unless `vault == real`; inside a decoy session
  the ordinary lock rows manage the *decoy* credential, and theme/pronoun/biometric prefs come
  from the decoy DB. There is no separate "decoy mode" flag surfaced anywhere. (4) **Bounded by
  a background reset.** The lifecycle listener sets `appVaultProvider` back to `real` on
  pause/hide, so a decoy session can't outlive an app switch and re-entry always re-chooses the
  vault via the PIN. Biometric unlock is always → real. (5) **No schema change / no new deps**
  — reuses SQLCipher + `flutter_secure_storage`; `EncryptedDatabase.open` gained an optional
  `fileName`, the two secure stores gained a `keyName`. Known gaps (→ §9): removing the decoy
  PIN leaves the decoy DB file; no lockout/backoff; DB key still not bound to the PIN. —
  worker: phase2.

- 2026-08-30 — **p2.1 biometric unlock is an opt-in shortcut *past* the PIN, behind a
  `BiometricGateway` seam, with `local_auth` set `biometricOnly: true`; no schema change.**
  Rationale: (1) **Seam, not a direct plugin call.** `local_auth` is a platform-channel plugin
  that throws in `flutter test`, so — exactly like `ReminderScheduler` (p1.7) and
  `BackupFileGateway` (p1.10) — the app depends on an `app`-side `BiometricGateway` interface
  (`canAuthenticate` / `authenticate → success|failed|unavailable`), the production
  `LocalAuthBiometricGateway` wraps the plugin, and `pumpOlf` injects `FakeBiometricGateway`
  (default: incapable, so every pre-p2.1 widget test is untouched). CI never loads the
  channel. (2) **Never a lock on its own.** The switch only shows once a PIN is set; the lock
  screen keeps full PIN entry; a failed/cancelled/unavailable result falls back silently. So
  biometric is purely "is it me?" and the app PIN stays the sole knowledge factor —
  `biometricOnly: true` deliberately refuses the *device* passcode as a stand-in, which keeps
  the model clean for the p2.2 decoy PIN. (3) **No schema change.** One `app_settings` key
  (`SettingKeys.biometricUnlock`, `'true'`/absent) via the p1.6 store; the PIN credential in
  the secure enclave is untouched; drift codegen is byte-identical. (4) **Native config is
  minimal and audited.** Android `MainActivity` → `FlutterFragmentActivity` (a `local_auth`
  requirement); `USE_BIOMETRIC` added to the manifest *with* an `audited:` comment so the
  dependency-audit still passes (38 rules); iOS gets `NSFaceIDUsageDescription`. `local_auth`
  is a Flutter-team, biometric-only package — not on the denylist. (5) **Still a UI-level
  gate** — like the PIN, biometric unlock does not wrap the DB key; binding the key to
  PIN/biometric with a real KDF stays a §9 follow-up. — worker: phase2.

- 2026-08-29 — **p1.11 loss / birth are two `CycleEventType` values on the dormant
  `cycle_events` table (no schema change); the cycle engine marks the interval they fall in as
  a pregnancy gap and the predictor stays silent across it.** Rationale: (1) `cycle_events` has
  been carried since v1 for exactly this; adding `pregnancyLoss` / `birth` enum values is a
  Dart-only change (drift stores the enum name in the existing TEXT column, codegen is
  byte-identical, a v1 DB opens unchanged) — **no `schemaVersion` bump, no migration**. (2) A
  pregnancy is not a cycle: `deriveCycles(periods, {pregnancyEvents})` flags the interval an
  event falls inside as `Cycle.isPregnancyGap`; `CycleStats` then uses only cycles **newer than
  the latest such gap** (`takeWhile`), so pre-pregnancy lengths never contaminate the current
  baseline, and `RobustPredictor` returns **`null` while the open cycle covers the event** —
  no date is projected across a loss / birth. The forecast resumes on its own once a period is
  logged (the thin post-event history makes it low-confidence, then sharpens) — no separate
  "resume" state machine. (3) `PregnancyRecoveryState` (`none` / `awaitingCyclesAfterLoss` /
  `postpartum`) is derived, drives **one** gentle home banner, and is `none` again the moment a
  period starts after the event. (4) Logging lives on its **own Settings screen** (sensitive,
  contained), not the day sheet; copy is "Pregnancy loss" / "Birth", non-clinical, and passes
  the p1.9 inclusive-language lint. (5) Full pregnancy / TTC / postpartum *modes* stay Phase 7
  — this is only the marker + engine handling. — worker: phase1.

- 2026-08-29 — **p1.10 backup is a versioned plaintext JSON document, AES-256-GCM'd under a
  PBKDF2 passphrase, saved through the platform document picker; no schema change; the KDF
  runs on the main isolate.** Rationale: (1) **Serializer separate from crypto.** `core`'s
  `BackupDocument` (`{format, formatVersion, appSchemaVersion, createdAt, tables}`) is
  independently unit-testable for "format is versioned" — `fromJson` rejects a newer version,
  non-int version, wrong `format`; an older version falls through to a forward-migration hook
  (empty for v1). `BackupService.export/import` copies rows **raw** (`SELECT *` → `{col:
  value}` maps; parameterised `INSERT` back) so raw SQLite values — including the integer
  timestamps drift stores for `DateTime` and the string names it stores for enums — round-trip
  byte-for-byte, making "reproduces all data exactly" true by construction. `import` wipes and
  re-inserts every table in **one transaction** (all-or-nothing) and refuses a backup whose
  `appSchemaVersion` differs from the running build. A `tableOrder` constant + a test that
  asserts it equals the live schema means adding a table fails loudly here. (2) **AES-256-GCM
  under PBKDF2-HMAC-SHA256** (210k iterations, stored in the file header so it can rise later)
  via the new `cryptography` package (pure Dart, Dart-ecosystem, **not** ad/analytics —
  denylist is unaffected) added to `core`. A wrong passphrase fails the GCM tag →
  `BackupPassphraseException`, kept distinct from `BackupFormatException` so the UI can say
  "wrong passphrase" vs "not a backup file". Container: `OLFBK1` magic + BE header length +
  public JSON header + ciphertext. (3) **`file_picker`** (added to `app`) for the save/open
  dialogs — it uses SAF / `UIDocumentPicker`, so **no storage permission** and no manifest
  change; confined to `backup_gateway.dart` behind a `BackupFileGateway` interface with a fake,
  exactly like p1.7's notification scheduler, so CI never loads the plugin channel. (4) **No
  schema change / no migration** — backup only reads and writes tables that already exist.
  (5) The KDF runs on the main isolate for now (one-off, explicit user action); moving it to a
  background isolate, gzip before encrypt, and deriving the DB key from the same passphrase are
  §9 follow-ups. — worker: phase1.

- 2026-08-29 — **p1.9 theme + pronoun baseline: no schema change, "golden tests" shipped as
  both-theme render tests, inclusive copy locked in by a source-scanning lint.** Rationale:
  (1) **No schema bump** — `theme_mode` (`system`/`light`/`dark`) and `pronouns` (a `Pronouns`
  enum name; absent → `unspecified` → they/them) are two more `app_settings` keys via
  `SettingKeys`, reusing the p1.6 store. (2) The inline `ThemeData` from `main.dart` is
  extracted to `app/lib/src/theme/olf_theme.dart` as `olfTheme(Brightness)` — same neutral
  sage seed `0xFF4C6B5A` (deliberately not pink), Material 3, one shared `Card`/`AppBar`/text
  baseline so light and dark are consistent; `OlfApp` becomes a `ConsumerWidget` that watches
  `themeModeProvider` and passes `theme` + `darkTheme` + the chosen `themeMode`. (3) The
  acceptance criterion "every screen renders correctly in both themes" is met by
  `app/test/theme/theme_render_test.dart` — each main screen (home, calendar with data, day-log
  sheet, meds, settings, first-run, PIN unlock) pumps under both brightnesses asserting **no
  exception, no `RenderFlex` overflow, and `Theme.of(context).brightness` matches**. **Pixel
  goldens (`matchesGoldenFile`) are deferred** — they need golden CI infra + pinned fonts to
  not be flaky on the ubuntu runner (§9). (4) The pronoun model is pure-Dart
  `core/lib/src/personalization/pronouns.dart` (`formsFor` with `unspecified`→they/them,
  `pronounExampleSentence` as the first live consumer, storage round-trip). (5) Existing copy
  was already second-person / neutral; p1.9 **locks it in** with `docs/inclusive-language.md`
  (human checklist) + `app/test/copy/inclusive_language_test.dart`, which scans every string
  literal under `app/lib` and `core/lib` against a denied-phrase regex list and fails the
  build on a match (bare pronouns are **not** denied — the pronoun feature needs them). —
  worker: phase1.

- 2026-08-29 — **The p1.8 PIN is a UI-level gate, not a cryptographic boundary; no schema
  change; a new `AppGate` root layers first-run → PIN → home.** Rationale: (1) the database is
  already encrypted at rest with a key in the platform secure enclave, so in Phase 1 the PIN
  only decides which screen `AppGate` shows — it does **not** derive or wrap the DB key.
  Binding the key to the PIN with a real KDF, plus biometric unlock / decoy PIN / lockout /
  scheduled deletion / background masking, is Phase 2 (the plan already scoped those out).
  This is stated in `core/lib/src/security/pin.dart` and `docs/privacy-and-lock.md` so nobody
  mistakes it for more than it is. (2) The PIN **secret** is a salted iterated-HMAC-SHA256
  hash (`PinCredential`) in `flutter_secure_storage` — never in the DB, never plaintext;
  **presence of that credential is the "lock is on" signal**, so there is no second flag to
  drift. Work factor is a modest 30k iterations to keep on-device unlock snappy on the main
  isolate — raising it / moving it off-isolate is a §9 follow-up. (3) `crypto` (Dart-team
  package, not ad/analytics) added as a `core` direct dep. (4) The only new persisted bit —
  `onboarding_complete` — reuses the p1.6 `app_settings` store (the §7 p1.6 note anticipated
  this), so **p1.8 has no schema bump and no migration**. (5) Disclaimer copy is four named
  constants in `onboarding/disclaimers.dart` (data on-device / never sold, HIPAA doesn't
  apply, not medical advice, not a contraceptive) so a content test pins them and p1.9's
  language sweep has one target. — worker: phase1.

- 2026-08-29 — **Medications, birth control and the one daily reminder are three additive
  tables at `schemaVersion` 6; the reminder stores no free text, and the notification plugin
  sits behind a `ReminderScheduler` interface (p1.7).** New tables: `medications(id, name,
  dosage?, notes?, archived_at?, created_at, updated_at)` — a soft-archived list, name
  validated, mirroring `symptom_types`; `birth_control_entries(id, method, started_on,
  ended_on?, notes?, created_at, updated_at)` — a *history*, `ended_on IS NULL` = current, and
  `switchTo` closes the previous open row so a method change can later be lined up against
  symptoms; `reminders(id, kind UNIQUE, hour, minute, enabled, created_at, updated_at)` — a
  table (not an `app_settings` key) so Phase 4's granular system extends it, but p1.7 keeps
  exactly one row. Rationale: (1) **no free-text column on `reminders`** — the notification
  title/body are fixed generic constants in `app/lib/src/reminders/reminder_scheduler.dart`
  (`'olf'` / `'Time for your daily check-in.'`), so no medication name, dosage or method can
  reach a lock screen; the acceptance criterion "reminder text contains no health details" is a
  compile-time fact, asserted in `reminder_controller_test.dart`. (2) The **pure schedule
  model** (`ReminderSchedule` + `nextOccurrence` + `validateReminderTime`) lives in `core`;
  the OS wrapper (`flutter_local_notifications`) is confined to one app file behind an
  interface with a fake, so widget tests never load a platform channel and Phase 4 can widen
  the wrapper without touching `core`. (3) New app deps `flutter_local_notifications` +
  `timezone` + `flutter_timezone` — none are ad/analytics/crash SDKs, none are denylisted; the
  reminder is *inexact* (`AndroidScheduleMode.inexactAllowWhileIdle`) so it needs **no
  exact-alarm permission**; the two app-manifest permissions (`POST_NOTIFICATIONS`,
  `RECEIVE_BOOT_COMPLETED`) each carry an `audited:` comment. (4) Birth control is a history,
  not a single value, for the same reason symptoms are dated — a later phase correlates.
  — worker: phase1.
- 2026-08-29 — **BBT is stored in Celsius; mucus is a Billings enum; both are day-keyed tables,
  and mucus feeds the fertile window only at the display layer (p1.6).** `schemaVersion` bumped
  to **5**: `bbt_entries(date PK, temp_celsius REAL, created_at, updated_at)`,
  `cervical_mucus_entries(date PK, type TEXT, created_at, updated_at)`, and a general
  `app_settings(key PK, value, updated_at)` key/value store. Rationale: (1) storing temperature
  **canonically in °C** and treating °C/°F as a display preference keeps one number in the DB
  and all rounding in one file — the alternative (store-as-entered) makes every read
  unit-aware. (2) `CervicalMucusType { dry, sticky, creamy, watery, eggWhite }` is a small
  fixed ordered scale, not a user vocabulary, so it's an enum column, not a catalogue like
  symptoms. (3) A generic `app_settings` table (rather than a bespoke column) is the reusable
  home for the unit choice and for p1.8's PIN-enabled flag / p1.9's theme + pronoun. (4) The
  p1.4 acceptance "mucus feeds the fertile-window display" is met with a **display-layer merge**
  (`observedFertileWindow(...)` → an extra "Fertile signs (from your notes)" line) rather than
  by changing `RobustPredictor` or `CyclePrediction` — the `Predictor` seam stays pristine for
  Phase 3's swap, and `p1.4`'s tests are untouched. BBT and mucus are day-keyed and unlinked
  from `periods`, exactly like `daily_flows`. The per-cycle BBT chart is a self-contained
  `CustomPaint` — no charting package, so the dependency denylist surface doesn't grow.
  — worker: phase1.
- 2026-08-29 — **Symptoms are a user-editable catalogue + per-(day, type) presence rows
  (p1.5).** `schemaVersion` bumped to **4**: `symptom_types(id, name, sort_order, is_built_in,
  archived_at?, created_at, updated_at)` is the vocabulary; `daily_symptom_entries(date,
  symptom_type_id → symptom_types ON DELETE CASCADE, created_at, PRIMARY KEY(date,
  symptom_type_id))` is the log. Rationale: a catalogue table (not a fixed enum) is what makes
  "add / rename / reorder your own symptoms" a data change rather than a code change; a
  composite-key presence row makes multi-select logging idempotent (toggle = insert-or-ignore /
  delete) with nothing to validate, so day logging is plain CRUD while the catalogue carries
  the validation (`validateSymptomName`: empty / >40 / case-insensitive duplicate among active
  names). **Removal is a soft archive** (`archived_at`), not a delete: a removed symptom leaves
  the pickers but its historical entries stay meaningful and its name is never silently reused.
  The ~11 built-in names are gender-neutral and seeded by `_seedBuiltInSymptoms()` from **both**
  `onCreate` and the `from < 4` upgrade, so fresh and upgraded databases are identical. Entries
  are **presence-only in v1** — no severity/scale; mood & energy are modelled as ordinary
  toggle symptoms, not sliders. Entries are unlinked from `periods` (same reasoning as
  `daily_flows`). On the calendar, tapping a **non-period** day now opens the symptom day sheet
  (a period day still opens the flow sheet, which gains an "Add symptoms" button); the sheet
  offers "Start a period" so p1.1's tap-an-empty-day affordance survives. — worker: phase1.
- 2026-08-28 — **Prediction v1 is a stats-based `RobustPredictor` behind a `Predictor` seam
  (p1.4).** `Predictor.predict({cycles, today}) → CyclePrediction?` in `core`; Phase 3's
  adaptive/backtested engine replaces the implementation with no call site change. **No schema
  change** — the forecast derives from `cyclesProvider` on every read, so editing history
  recomputes it on the same screen. v1 maths: anchor on the **last logged period start**,
  project the median recent (≤ 12, non-gap) cycle length, widen to `[anchor + shortest,
  anchor + longest]` with a ±1-day floor so a date is never claimed to the day. Fertile window
  = `expected − 14` (luteal phase treated as a fixed 14 days for v1) ± sperm/ovum viability
  → a 7-day `DateRange`. **A late period never rolls the estimate forward**: `expected` depends
  only on the anchor, and once `today` passes the window the status is `overdue` and the UI
  shows a "Period check-in" ("N days later than usual" + a *Log period start* button), not a
  new future date. Confidence is a coarse three-bucket hint (`high` = regular + ≥ 3 cycles;
  `medium` = regular/mostly-regular + ≥ 2; else `low`; any likely gap → `low`). Rationale:
  ships the headline differentiator as *correct, humble, correctable* now without pretending
  to Phase 3's accuracy; every date is a range with an uncertainty note; the seam keeps the
  swap cheap. Raw min/max (not percentiles), point-anchored fertile window, and the fixed
  luteal length are follow-ups in §9. — worker: phase1.
- 2026-08-28 — **Cycles are derived on read, never stored (p1.3).** `core/lib/src/cycle/`
  turns the `periods` list into `List<Cycle>` (start-to-start pairing; newest period opens the
  current cycle) plus a `CycleStats` summary — median cycle / period length, min–max range, a
  coarse `CycleRegularity` (spread-based: ≤ 4 / ≤ 9 / more), and a `hasLikelyGap` flag for
  intervals over **45** days that more likely mean a missed entry. **No schema change** in
  p1.3. Rationale: derived data stored is derived data that can go stale or need its own
  migration; recomputing off `periods` on every change keeps "editing history changes the
  numbers" true for free and matches p1.1's no-forward-cascade rule. **No 28-day (or any)
  default anywhere** — with too little history every figure is `null` and the UI asks for more
  logging. Regularity thresholds and the gap cutoff are heuristics flagged for revisit in §9.
  — worker: phase1.
- 2026-08-28 — **Per-day flow is its own table, unlinked from `periods` (p1.2).** Schema
  `schemaVersion` bumped to **3**: new `daily_flows(date PK, intensity, clot_size?, created_at,
  updated_at)` — one row per calendar day, keyed by the date itself (no autoinc id, no FK to
  `periods`). Rationale: flow is an observation about a *day*, not about a period row; keeping
  them unlinked means editing or deleting a period never cascades onto what was logged, and the
  same day can carry flow whether or not a period is recorded for it. `setFlow` upserts on
  `date` and preserves `created_at` (a correction is auditable). No validation — any intensity
  is valid and clots are optional — so `DailyFlowRepository` is plain CRUD; the UI decides when
  to offer logging (period days + today). Migration `from < 3` is purely additive. No new
  dependencies. **Interaction change from p1.1:** tapping a period day on the calendar now
  opens the flow quick-log sheet (the §4 fast path) instead of the period-dates editor; the
  sheet's "Edit period dates" button and the "Add a period" button preserve p1.1's editor
  entry points. — worker: phase1.
- 2026-08-28 — **Periods are a dedicated interval table, not paired events (p1.1).** Schema
  `schemaVersion` bumped to **2**: new `periods(id, start_date, end_date?, created_at,
  updated_at)`. `cycle_events` stays as the point-in-time event log for p1.11 (loss / birth /
  postpartum). Rationale: overlap checking, editing and deletion are natural on an interval
  row and awkward on paired start/end events. The overlap / impossible-range invariant is
  enforced in `PeriodRepository` (`addPeriod` / `updatePeriod` throw
  `PeriodValidationException`), **not** by DB constraints, so one rule covers every screen and
  stays unit-testable; "today" is an injected clock so it is deterministic and offline.
  `CycleEventRepository` is retained in `core` but unused by the app. No new dependencies —
  the month calendar is a hand-rolled grid. — worker: phase1.
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
  first-frame jank appears; revisit the DB directory choice when p1.10 (backup/export) lands.
- **Adopt `drift_dev schema` snapshot tooling** for the next migration. The p1.1 v1→v2
  migration test (`core/test/db/period_migration_test.dart`) hand-builds the old schema; the
  snapshot generator would let each future upgrade be tested step-by-step from a dumped
  schema. (Was a p0.4 follow-up; deferred again — a hand-rolled test was enough for three
  small additive migrations, v1→v2, v2→v3 and v3→v4.) — noted by worker: phase1 during p1.1,
  still open after p1.5.
- **p1.1 follow-ups:** period-length sanity ceiling (a `tooLong` validation error, e.g. warn
  past ~15 days) — deliberately left out of p1.1, which blocks only overlaps and impossible
  ranges; a one-tap "period ended today" quick action from the home summary (the editor
  already supports adding an end date). — noted by worker: phase1.
- **p1.2 follow-ups:** flow is loggable only on period days + today (the calendar tap opens the
  period editor on any non-period day). A "log flow for an arbitrary past day without a period"
  entry point (spotting between periods) is not yet designed — revisit alongside p1.11 events
  or a dedicated symptom-logging slice. The `daily_flows` row has no "notes"/free-text field;
  add if a later slice needs it. — noted by worker: phase1 during p1.2.
- **p1.3 follow-ups:** the `CycleStats` regularity thresholds (spread ≤ 4 `regular`, ≤ 9
  `mostlyRegular`) and the 45-day likely-gap cutoff are heuristics chosen from typical ranges,
  not tuned against data — revisit once p1.4's predictor and real histories exist (they may
  want to share one definition of "irregular"). Also: the history list is still period-first;
  a dedicated per-cycle detail view (this cycle's flow, symptoms, length vs. your typical) is
  later work. And `deriveCycles` treats every gap as a single long cycle plus a flag — it does
  not try to *infer* how many cycles were missed. — noted by worker: phase1 during p1.3.
- **p1.4 follow-ups (feed Phase 3):** `RobustPredictor`'s next-period window is the raw recent
  min/max around the median — no percentile/MAD trimming, so one outlier cycle widens it a lot.
  The fertile window is anchored on the point estimate only (not widened by the next-period
  uncertainty) and assumes a **fixed 14-day luteal phase** — p1.6's BBT / cervical-mucus inputs
  should refine ovulation timing rather than this constant. Confidence is a 3-bucket hint with
  hand-picked thresholds; no backtesting / calibration yet. `predictionProvider` reads
  `DateTime.now()` directly (fine for v1; a `clockProvider` would make the late-state widget
  test time-independent). — noted by worker: phase1 during p1.4.
- **p1.5 follow-ups:** symptom entries are **presence-only** — no per-entry severity/scale, and
  no free-text note per day; add a severity column (or a notes field) if a later slice needs
  it. Mood & energy are plain toggle symptoms, not ordered scales — a dedicated scale widget is
  deferred. The "Recent symptoms" list resolves names against the **active** catalogue only, so
  a day that has an archived symptom still counts on the calendar but that symptom's name drops
  out of the list; a history view that resolves archived names (or a per-cycle "this cycle's
  symptoms" rollup in `_History`) is later work. Cervical-mucus / discharge is a single toggle
  symptom here — the structured Billings-style classification that feeds the fertile window is
  **p1.6**. `reorderTypes` rewrites every `sort_order` on each drag (fine at this scale; a
  sparse/fractional index would avoid the rewrite). No cap on the number of custom symptoms.
  — noted by worker: phase1 during p1.5.
- **p1.6 follow-ups:** `observedFertileWindow` is a crude signal — it just brackets the
  fertile-quality mucus days plus one; it does not detect a "peak day" / drop-off, cross-check
  against the BBT thermal shift, or narrow the statistical estimate (it only shows alongside
  it). The BBT chart has **no coverline / thermal-shift detection** and no smoothing — it is a
  plain plot; a proper biphasic-shift marker and a fertile-window derived from BBT+mucus
  together is Phase 3 territory (and would let `lutealPhaseDays` stop being a fixed 14). No
  outlier rejection on BBT points (a disturbed-sleep reading skews the line). `temp_celsius`
  has no DB `CHECK` — plausibility is repository-only, so a raw SQL insert could store nonsense.
  Only one reading per day (no "took it twice" reconciliation). The °C/°F choice lives in
  `app_settings` but there is no Settings screen yet — it is only reachable via the temperature
  dialog's toggle; a real settings surface is p1.8/p1.9. Mucus is a single daily observation
  (no sensation vs. appearance split, no "checked, saw nothing" vs. "didn't check").
  — noted by worker: phase1 during p1.6.
- **p1.7 follow-ups:** the daily reminder is **inexact** (`inexactAllowWhileIdle`) — the OS may
  fire it minutes late and it deliberately does not request `SCHEDULE_EXACT_ALARM`; a
  minute-accurate option is Phase 4. Only **one** reminder, one time a day, one `ReminderKind`
  — no per-medication reminders, no "twice daily", no snooze, no day-of-week filter (all Phase
  4, which the `reminders` table is shaped for). Local-timezone resolution falls back to **UTC**
  if `flutter_timezone` fails, so a reminder could be off by the UTC offset on an
  unusual device; there is no re-anchor on a travel/DST change beyond what
  `matchDateTimeComponents: DateTimeComponents.time` gives. Tapping the notification just opens
  the app — no deep link to the meds screen. `hour`/`minute` have no DB `CHECK` (repository-only
  validation, like `temp_celsius`). Birth control: no reminder tie-in (e.g. "pill at 9pm"), no
  pack/placebo tracking, no injection-due-date maths; the method history is recorded but nothing
  reads it yet. Medications: a plain list — no schedule, no per-dose log, no interaction/refill
  data, no reminder per medication. The meds screen is reachable only from a home AppBar icon;
  a real Settings hub is p1.8/p1.9. The `ReminderScheduler` real path (`zonedSchedule` firing
  on a device) is exercised only manually / on-device — the CI coverage is the wrapper contract
  test with a fake, per the task's "test around the notification scheduling wrapper".
  — noted by worker: phase1 during p1.7.
- **p1.8 follow-ups (mostly Phase 2 by design):** the PIN is a screen gate only — it does not
  wrap the SQLCipher key, so someone with the unlocked device / a file dump still gets the DB
  via the enclave key. No **biometric** unlock, no **decoy PIN** + decoy dataset, no
  **failed-attempt lockout / backoff** (unlimited guesses), no **scheduled auto-deletion**, no
  **screenshot / app-switcher masking** (§3 "blur when backgrounded" — only re-lock-on-pause
  is done). PIN hashing (iterated HMAC-SHA256, 30k) runs on the **main isolate** (~150 ms
  desktop, more on a phone) and the work factor is deliberately low for responsiveness — Phase
  2 should move it to a background isolate and/or use a real KDF that also derives the DB key.
  `PinCredential` has no versioned re-hash path if the work factor changes later. The
  re-lock-on-background timing has no grace period (instant re-lock even on a quick app
  switch). The first-run screen has no "why does this matter" deep-dive or links, and no
  language toggle. `SettingsPage` currently holds only the app lock; export/import (p1.10) and
  theme/pronoun (p1.9) join it there. — noted by worker: phase1 during p1.8.
- **p1.9 follow-ups:** **pixel goldens are deferred** — the both-theme render tests assert "no
  exception / no overflow / brightness matches" but not exact pixels; a real
  `matchesGoldenFile` suite needs golden CI infra + a pinned font so it is not flaky on the
  ubuntu runner (candidate for a Phase 2/5 polish slice). Only **one live consumer** of the
  pronoun setting (`pronounExampleSentence` in Settings) — no screen copy is actually
  personalised yet; wiring `formsFor` into real strings (prediction card, reminders, day sheet)
  is future work, and doing so needs those strings to move off plain literals, which the
  inclusive-language lint currently assumes. The lint is **literal-only** — it cannot see
  copy assembled by interpolation/concatenation from non-literal parts, asset text, or store
  listings. `themeMode` is app-wide only — no per-screen or scheduled (e.g. sunset) dark mode,
  and no true-black OLED variant. No in-app font-scale / high-contrast / reduce-motion controls
  (rely on OS settings for now). The theme is a single seed colour — no user theme/accent
  choice. — noted by worker: phase1 during p1.9.
- **p1.10 follow-ups:** the PBKDF2 KDF (210k iterations) runs on the **main isolate** — a
  one-off explicit action, but a large database on a slow phone could jank for a second or two;
  move it to a background isolate (and consider Argon2id). The JSON document is **not
  compressed** before encryption — fine at Phase 1 data volumes, add gzip when history grows.
  Backup and the DB-at-rest key are **independent secrets** (backup passphrase vs. the enclave
  key); a future revision could derive both from one passphrase. **No integrity of the backup
  set** — nothing tracks how many backups exist or where. p2.3 makes every backup written
  *after* a window is set exclude purged data (purge-before-export), but scheduled
  auto-deletion still does **not** reach `.olfbackup` files already saved to disk (§9(11) /
  requirements "delete means delete") — see the p2.3 follow-up. Restore is **whole-database replace only** — no merge, no selective import, no
  "preview before restoring", and it hard-refuses a backup from a different `schemaVersion`
  rather than migrating it (so a backup taken now cannot be restored after the next schema
  bump until a format migration is written). The real `file_picker` SAF/UIDocumentPicker path
  is manual/on-device only in CI (the `BackupFileGateway` fake covers the seam), like p1.7's
  scheduler. `.olfbackup` is not registered as an app file type, so "open with olf" from a
  file manager does nothing. No auto/periodic backup, no cloud target. — noted by worker:
  phase1 during p1.10.
- **p1.11 follow-ups:** a loss / birth is only loggable from **Settings → Cycle** — there is no
  affordance to record one on a tapped calendar day, and the event day is **not drawn** on the
  month calendar. `PregnancyRecoveryState` flips straight to `none` on the first post-event
  period rather than easing the forecast back over a few cycles (the predictor's own
  low-confidence ramp is the only softening). No pregnancy / TTC / postpartum **modes**, no
  due-date / gestational-age tracking, no tailored postpartum symptom set — all Phase 7. Banner
  copy is fixed and not pronoun-personalised (the p1.9 infra exists but isn't wired here).
  Multiple losses / births are stored, but only the **most recent** drives the banner and the
  stats reset. `deriveCycles` treats an event dated exactly on a period-start day as belonging
  to no interval (documented + tested), so a same-day "loss, then period resumes" needs the
  period dated at least a day later for the stats to reset. — noted by worker: phase1 during
  p1.11.
- **p2.1 follow-ups:** biometric unlock is still a **UI-level gate** — it does not derive or
  wrap the SQLCipher key (same limitation as the PIN); binding the DB key to the PIN/biometric
  with a real KDF, and moving the PIN hash off the main isolate + raising its work factor,
  stay open (carried from p1.8). No **failed-attempt lockout / backoff** on either the PIN or
  the biometric retry button — that is p2.4-adjacent hardening. The auto-prompt fires once per
  lock-screen mount; it does **not** re-fire if the user backgrounds and returns while still on
  the lock screen (they use the "Use biometrics" button). `biometricOnly: true` means devices
  with only a passcode (no enrolled fingerprint/face) can't use the shortcut by design —
  revisit if users ask for device-credential fallback. The real `LocalAuthBiometricGateway` is
  not unit-tested (glue over a channel), matching the p1.7 precedent; a device/integration
  test could be added to the nightly. — noted by worker: phase2 during p2.1.
- **p2.2 follow-ups:** (a) turning the decoy PIN **off** leaves `olf-decoy.db` on disk — it is
  just unreachable; a real "delete the decoy space" action (and wiping it) is open. (b) The
  decoy vault opens with **default preferences** (system theme, they/them, biometric off) —
  an owner who runs a heavily-customised real app might notice the difference; seeding the
  decoy DB with a copy of a few innocuous prefs on creation would close that. (c) No
  **failed-attempt lockout / backoff** still (shared with p2.1). (d) The DB key is still not
  bound to the PIN — each vault's SQLCipher key sits in secure storage independent of its PIN,
  so an attacker with a secure-store dump + the decoy PIN still can't read the real DB, but an
  attacker with the real key doesn't need any PIN. Binding each vault's key to its PIN with a
  real KDF is the p1.8/p2.1 carry-over. (e) `_submit` awaits `appDatabaseProvider.future`
  after switching vault; if the decoy DB fails to open the user lands on the fail-safe screen
  rather than the lock screen — acceptable but not graceful. (f) The decoy DB is created on
  first decoy unlock, so the very first duress use has a brief "opening database" spinner the
  real vault wouldn't show on a warm start. — noted by worker: phase2 during p2.2.
- **p2.3 follow-ups:** (a) **§9(11) — already-saved backups are not scrubbed.** Scheduled
  auto-deletion purges the live DB and every *new* export, but the app keeps no registry of
  where past `.olfbackup` files were saved (the `BackupFileGateway` just streams bytes to an
  OS save dialog), so it cannot retroactively open and rewrite them. Options for a later
  slice: a "known backups" list the app maintains + a "re-scrub my backups" action, or making
  restore itself apply the current window on import. (b) **No background/periodic sweep** —
  the purge runs on app launch (past the lock), on window change, and before an export; an
  app left open for days past a cutoff boundary won't purge until the next launch/export.
  A `WorkManager`/`BGTaskScheduler` periodic job is Phase 4-adjacent. (c) **Coarse windows
  only** (6 months / 1–3 years) — no custom "keep N days" or per-data-type retention. (d)
  **Hard delete, no undo** — there is no trash/grace period; the confirmation dialog is the
  only safety net. (e) The startup sweep runs **on every launch** when a window is set (it's
  cheap — indexed `DELETE`s, usually zero rows — but it is not throttled to "once a day").
  (f) `RetentionService.sweep` takes `now` from the caller (`DateTime.now()` in
  `RetentionController`); a `clockProvider` would make the widget test fully time-independent
  (shared with the p1.4 follow-up). — noted by worker: phase2 during p2.3.
- **p2.4 follow-ups:** (a) **All-or-nothing.** `FLAG_SECURE` and the app-switcher mask are
  held for the whole app lifetime — there is no per-screen scoping (e.g. allow a screenshot
  of an empty calendar but not the day sheet) and no user opt-out for someone who wants to
  screenshot a chart for a clinician. A `SecureScreen` marker widget + a ref-counted
  controller is the shape if this is wanted. (b) **iOS screenshots/recordings are not
  blocked** — there is no OS API; only the app-switcher snapshot is covered (natively in
  `AppDelegate` + the Flutter shield). iOS `UIScreen.isCaptured` screen-recording *detection*
  (show the mask while recording) is a possible add. (c) The native pieces
  (`MainActivity.kt` FLAG_SECURE handler, `AppDelegate` cover) are **compile-checked by the
  `build` CI job only** — no device/integration test, matching the p1.7 / p2.1 precedent for
  channel glue; the nightly `integration_test` job could gain a lifecycle-mask check. (d) The
  mask shows on *every* non-`resumed` transition including a brief Control-Centre pull-down —
  intentional (fail-safe) but a short debounce could reduce the flicker; not worth it yet. (e) The
  cover is a plain themed panel; a deliberate branded splash would look less like a glitch.
  — noted by worker: phase2 during p2.4.
- **p2.5 follow-ups:** (a) The two consent switches (`analytics_opt_in`, `data_sharing_opt_in`)
  are **forward-looking gates with no consumer yet** — nothing in the app reads them, because
  the app collects and shares nothing. Whichever future slice adds a metric or a share must
  check the relevant provider *and* add its specifics to the "What we would ever collect"
  policy section (there is no test binding the two together yet). (b) The policy is **English
  only** and the "last reviewed" date is a hand-maintained constant
  (`privacyPolicyLastUpdated`) — a copy change that forgets to bump it only trips the
  "four-digit year" check, not staleness. (c) No **acceptance/version tracking** — the user
  is never asked to acknowledge a policy change (by design: "continued use never counts as
  agreement", and any new practice is opt-in), but if a jurisdiction ever requires explicit
  re-consent this needs a stored policy-version key. (d) The MHMDA/SB370 alignment is a
  good-faith reading, **not a lawyer review**. (e) Educational explainers (HIPAA gap,
  law-enforcement reality, delete walkthrough) are deliberately **out of scope → p2.7**.
  — noted by worker: phase2 during p2.5.
- **p2.6 follow-ups:** (a) **Certificate pinning is designed, not enforced.** `OlfHttpClient
  .certificatePins` is an empty map and `_checkPins` *throws* for any host added to it — so
  the first slice that adds a real backend host must implement enforcement (a `SecurityContext`
  trusting only the pinned chain, or a leaf-SPKI check in a `connectionFactory` /
  post-connect) and add the matching `<pin-set>` to the Android config. `dart:io` has no
  built-in SPKI-pinning helper; if a small audited package is cleaner at that point, add it
  **then** — it is not pulled in speculatively now (ponytail). (b) The `OlfHttpClient` seam
  lives in `app/` because all near-term network features are app-side; if a **core**-side
  feature (e.g. a sync engine) needs it, the ~1-file seam moves to `core/lib/src/net/`
  (it is pure `dart:io`, no Flutter). (c) The source-bypass scan
  (`app/test/net/transport_security_test.dart`) is **substring/regex based** — it catches
  `HttpClient` / `package:http` / raw `Socket`, but a determined bypass via reflection or a
  transitively-added client isn't caught; the denylist gate is the backstop for the latter.
  (d) No **runtime** proof that cleartext is blocked on-device — the checks are static
  (config scan + seam unit test); a nightly `integration_test` that asserts an `http://`
  request throws could be added. (e) `usesCleartextTraffic="false"` in the main manifest is
  assumed not to break `flutter run` hot-reload on current Flutter (it does not — the VM
  service uses `adb forward` / localhost, not the cleartext-guarded APIs); revisit if a dev
  reports otherwise. — noted by worker: phase2 during p2.6.
- **p2.7 follow-ups:** (a) The explainers are **English only** and are static `const` copy —
  no "last reviewed" marker, so a legal-landscape change (e.g. a new state consumer-health
  law, or an actual federal one) has to be caught by hand. (b) The content is **not a lawyer
  review** — same good-faith-reading caveat as the p2.5 policy; the HIPAA and
  law-enforcement explainers make legal-adjacent claims. (c) The delete explainer **describes**
  uninstall but can't perform it — there is no in-app "wipe everything now" button (uninstall
  is the OS's job); a `core`-side "delete all data" action that clears the vault + secure
  storage without uninstalling is a possible add for people who want to stay installed. (d)
  The "~9% take a protective action" framing is addressed only by the Backup & restore
  hand-off; there is no measurement (and won't be — no analytics) of whether users reach or
  act on these screens. (e) The tone check is a **fixed denylist** of alarmist words, not a
  readability or reading-level check. — noted by worker: phase2 during p2.7.
- **p2.9 follow-ups:** (a) **`ci.yml` itself is still editable in a PR.** The wiring-lock test
  makes weakening the audit *visible* (it fails the `test` job) but a reviewer could still
  approve a PR that changes both the workflow and the test together. On a solo repo the
  release-checklist self-review is the backstop; a CODEOWNERS rule on `.github/` +
  `dependency-denylist.txt` requiring a second approver is the real fix once there is a
  second maintainer. (b) **The audit still only sees pub packages.** Native Gradle/CocoaPods
  SDKs added directly are not in `pubspec.lock`; the threat model (p2.8) and the release
  checklist call this out but there is no mechanical gate (candidate: parse
  `settings.gradle` / `Podfile.lock` if native deps are ever added). (c) **"Security
  reviewer" is a role with one holder.** The escalation path is documented but not enforced
  by tooling — it relies on the maintainer following it. (d) The `jq` dependency in `ci-ok`
  is fine on `ubuntu-latest` (preinstalled) but is a new assumption vs. the previous
  `grep`-only step. — noted by worker: phase2 during p2.9.
- (add more here)

## 10. Orphaned / cut work

Record abandoned branches, superseded designs, and cut features here so history is legible.

- (none yet)
