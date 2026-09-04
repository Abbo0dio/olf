# Release checklist

Run through this before tagging a release build. Items marked **BLOCKER** must
be green — a release does not go out with any of them red, and none of them can
be waived in CI.

## Blockers

- [ ] **BLOCKER — `CI OK` is green on the release commit.** This aggregates
      format, analyze, test, dependency-audit, and build.
- [ ] **BLOCKER — dependency audit passed.** The `dependency-audit` job ran and
      its result is `success` (not skipped). No advertising / analytics /
      tracking package anywhere in `core/pubspec.lock` or `app/pubspec.lock`;
      no un-audited Android permission; transport config still TLS-only. This
      gate is un-waivable — if it is red, follow the escalation path in
      [`dependency-audit.md`](dependency-audit.md#release-blocker-p29) rather
      than changing the gate. Security-reviewer sign-off is recorded in any PR
      that touched `.github/dependency-denylist.txt`.
- [ ] **BLOCKER — no new runtime dependency slipped in unreviewed.**
      `git diff <last-release>..HEAD -- '**/pubspec.yaml' '**/pubspec.lock'`
      reviewed; every addition is intentional and noted in its PR.
- [ ] **BLOCKER — threat model is current.**
      [`threat-model.md`](threat-model.md) has a Review-log entry for the
      current phase (the `threat_model_doc_test` guard enforces this in CI).

## Checks

- [ ] Version and build number bumped.
- [ ] Changelog / release notes updated.
- [ ] **Schema change (any PR that bumps `schemaVersion` in
      `core/lib/src/db/app_database.dart`)** — the same PR must, or the change
      does not ship:
  - [ ] Regenerate the drift snapshots: from `core/`, run
        `dart run drift_dev schema dump lib/src/db/app_database.dart drift_schemas/`
        (refreshes the latest `drift_schema_vN.json`) then
        `dart run tool/dump_historical_schemas.dart` (rebuilds v1..v(N-1)), and
        regenerate the verifier helpers with
        `dart run drift_dev schema generate drift_schemas/ test/db/generated/`.
        Commit all of `core/drift_schemas/` and `core/test/db/generated/`.
  - [ ] Extend `core/test/db/migration_matrix_test.dart`: add the new version to
        the `from` loops and the `_tableCountAtVersion` map in
        `tool/dump_historical_schemas.dart`, and seed representative rows in any
        new table so the `v(old) → v(new)` path is covered with data.
  - [ ] The migration matrix and every per-feature `*_migration_test.dart` are
        green. A lossy or missing historical step is a real bug — fix the
        migration and add a test; do not adjust a snapshot to hide it.
  - [ ] Backup/restore still round-trips across the migration (the
        `v(old) → migrate → backup → restore` tests in the same file).
  - [ ] Older per-feature migration tests still there for context (see
        [`local-database.md`](local-database.md)).
- [ ] Android `debug` / `profile` manifests reviewed by eye if they changed
      (they are not scanned by the audit).
- [ ] **`perf-budget` job green on the release commit** — the release APK is
      within `.github/perf-baseline.json` + threshold
      ([`performance-budget.md`](performance-budget.md)). If the baseline was
      bumped since the last release, that bump has its own commit with the
      reason in its PR. The debug-build install-size report from the `build` job
      is a secondary sanity check.
- [ ] Privacy policy [`privacy-and-lock.md`](privacy-and-lock.md) and the
      in-app policy screen still match what the build actually does.
- [ ] **Discreet app icon (p5.4) verified on a device.** On a real device or
      emulator: Settings → Appearance → App icon → **Notes**, confirm the
      warning, and check the home-screen icon + label actually change (Android:
      after olf is reopened from the launcher) and that relaunch works. Switch
      back to **Default** and confirm it restores. Do this on an Android build,
      and on an iOS build too if iOS is in the release.

## Cutting the release (Android)

Once the blockers and checks above are green:

1. Bump `app/pubspec.yaml` `version:` and merge that to `main`. **Version number
   is chosen manually** per the versioning policy in `DEVELOPMENT_PLAN.md` §7
   (2026-09-04 entry): `1.x.x` = alpha (until every phase is `DONE`), `2.0.0` =
   the beta cut the moment the last phase closes; inside `1.x`, minor = new
   features shipped, patch = bug-fixes-only. `scripts/cut_release.sh` automates
   steps 1–3 below once the version bump (and any other release-prep edits) are
   committed on a branch.
2. Tag the release commit on `main`: `git tag vX.Y.Z && git push origin vX.Y.Z`
   (`X.Y.Z` must match `app/pubspec.yaml` — the workflow emits a `::warning::` on
   mismatch, it does not hard-fail).
3. `.github/workflows/release.yml` (`on: push: tags: ['v*']`) runs
   `flutter build apk --release` **signed** with the upload keystore and
   publishes `app-release.apk` to a new GitHub Release with generated notes.

**One-time setup** — the workflow needs four repository secrets or it fails
loudly instead of shipping an unsigned APK: `ANDROID_KEYSTORE_BASE64` (base64 of
the `.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`,
`ANDROID_KEY_ALIAS`. Back the keystore file up offline — losing it means a new
signing identity.

iOS is not distributed this way yet (Apple signing / TestFlight is later work).

## Who signs off

For now the maintainer holds every role. Where an item above asks for
"security-reviewer sign-off", that means an explicit written note in the PR
description saying what was reviewed and why it is acceptable — not a silent
merge. Keep it short; keep it in the PR so it is auditable later.
