### Phase 0 — Repo, workflow, CI

**Goal:** the repo exists, the workflow is enforced, and the app
builds and does exactly one real thing so Phase 1 has something to grow.

#### p0.1 — Initialise repository & workflow
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

#### p0.2 — Flutter workspace: `core` + `app`
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

#### p0.3 — CI gates: format, analyze, test, dependency audit, build
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

#### p0.4 — Encrypted local store + first real slice: *log that your period started today*
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

#### p0.5 — Device smoke: `integration_test` on an emulator/simulator (nightly)
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

#### p0.6 — Android release workflow (signed APK in GitHub Releases)
- **PR:** [#43](https://github.com/Abbo0dio/olf/pull/43)
- **Branch / worktree:** `ci/android-release-workflow` / `../olf-wt/release-apk`
- **Owner:** worker: phase0 (CI slice — sibling to p0.3 / p0.5, not part of a numbered phase's build)
- **Depends on:** p0.3 (CI gates), p0.4 (the app builds an APK)
- **Requirement refs:** requirements.md §3 (distribution), §6 (release discipline)
- **Goal:** Turn a `vX.Y.Z` tag on `main` into a published, **signed** Android release APK on
  the GitHub Releases page — a real install path for testers without a Play listing, with no
  manual build step and no chance of shipping a debug/unsigned artifact by accident.
- **Acceptance criteria:**
  - New `.github/workflows/release.yml`, `on: push: tags: ['v*']`, `permissions: contents:
    write`, single `ubuntu-latest` job, `working-directory: app`, using only the two actions
    already in `ci.yml` (`actions/checkout@v7`, `subosito/flutter-action@v2` @ `FLUTTER_VERSION
    3.35.5`).
  - Decodes `secrets.ANDROID_KEYSTORE_BASE64` → `app/android/app/upload.jks` and writes
    `app/android/key.properties` from `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_PASSWORD` /
    `ANDROID_KEY_ALIAS` (`storeFile=upload.jks`).
  - **Fails loudly** (guard step → `exit 1`) if `ANDROID_KEYSTORE_BASE64` is empty — a
    workflow named *Release* never emits an unsigned or debug-signed APK.
  - `flutter build apk --release` then `gh release create "$TAG" --generate-notes
    app/build/app/outputs/flutter-apk/app-release.apk` (built-in `gh`, `GH_TOKEN:
    github.token` — no new publishing action).
  - `app/android/app/build.gradle.kts` gains a `signingConfigs.release` that reads
    `key.properties` when present and points `buildTypes.release` at it; when `key.properties`
    is absent (local dev) the release build falls back to debug signing exactly as before, so
    `flutter run --release` still works with zero setup.
  - `.gitignore` covers `app/android/key.properties` and `app/android/app/*.jks` / `*.keystore`.
  - `docs/release-checklist.md` gains the tag→publish step; `README.md` gains a short
    *Install (Android)* section (Releases link, signed build, sideload via "install unknown
    apps"; one line that iOS is not distributed this way yet).
  - Non-hard-fail step: warn (`::warning::`) if the tag (minus leading `v`) ≠
    `app/pubspec.yaml` `version:`.
  - No new GitHub Action beyond checkout + flutter-action; **no new runtime dependency; no new
    Android permission** (the manifest is untouched, so `dependency-audit` stays green); `core`
    untouched; `ci.yml`'s existing jobs untouched.
- **Tests required:** `flutter build apk --release` locally with a throwaway keystore +
  `key.properties` produces a **signed** APK (the Gradle config compiles and signs; verified
  with `apksigner verify` / `keytool`); `release.yml` is well-formed YAML; full `core` + `app`
  suites + analyze + format + dependency-audit still green.
- **Notes / detail:**
  - The workflow is **separate from `ci.yml`** — tag-triggered only, not in `ci-ok`'s
    `needs:`, so it can never affect a PR's required check.
  - The four `ANDROID_*` secrets are created by the maintainer out of band; this slice only
    *consumes* them. Until they are set, the first tag push will fail at the guard step by
    design (loud, not silent).
  - `key.properties` / `*.jks` are git-ignored; the keystore only ever exists on the CI runner
    for the length of one job.
  - iOS release signing (Apple certs / provisioning / TestFlight) is deliberately **out of
    scope** — noted for a later CI slice.
  - **`GeneratedPluginRegistrant.java` is generated, not committed** (`git ls-files` confirms
    it is untracked). Flutter 3.35.5 correctly omits the `integration_test` dev-dependency
    plugin from a **freshly** generated release registrant, so `flutter build apk --release`
    succeeds on a clean checkout (which is what the runner has). A *stale* registrant from a
    prior debug/`flutter test integration_test/` run in the same tree does still break
    `--release` locally with `package dev.flutter.plugins.integration_test does not exist` —
    `flutter clean` fixes it. Not a workflow problem; recorded here so the next person who
    hits it locally knows why.
**Phase 0 exit gate:** CI enforces the worktree→PR→merge workflow (required `CI OK` check);
every PR builds a debug APK (Ubuntu) and an unsigned iOS build (macOS); p0.4 merged and the app
does one real thing (log a period, encrypted, "Day N", delete). p0.5 adds a nightly
`integration_test` run on a real Android emulator + iOS simulator (SQLCipher + key store
exercised for real). **Remaining caveat:** one-time manual install+launch on a physical Android
and physical iOS device is still open (p0.5 table above). Gate considered met for the purpose of
starting Phase 1. *(p0.6 — signed-APK release workflow — added later as a Phase 0 CI-family
sibling; not a gate item.)*

---
