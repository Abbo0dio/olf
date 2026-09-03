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
- [ ] Schema migrations, if any, have a migration test (see
      [`local-database.md`](local-database.md)).
- [ ] Android `debug` / `profile` manifests reviewed by eye if they changed
      (they are not scanned by the audit).
- [ ] Install-size report from the `build` job is within expectations (a hard
      budget on a release build is Phase 5).
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

1. Bump `app/pubspec.yaml` `version:` and merge that to `main`.
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
