# olf

Private, correctable period & cycle tracker. Local-first, no ad/analytics SDKs, ever.

- **What the product must do:** [`requirements.md`](./requirements.md)
- **Roadmap & task order:** [`DEVELOPMENT_PLAN.md`](./DEVELOPMENT_PLAN.md)
- **How to contribute:** [`CONTRIBUTING.md`](./CONTRIBUTING.md)
- **Accessibility (WCAG 2.2 AA) conformance:** [`docs/accessibility-conformance.md`](./docs/accessibility-conformance.md)

## Workspace layout

A two-package Dart/Flutter monorepo wired with **plain `path:` dependencies** (no Melos yet —
see `DEVELOPMENT_PLAN.md` §7):

| Path | Package | Purpose |
|------|---------|---------|
| [`core/`](./core) | `olf_core` | **Pure Dart, no Flutter dependency.** Domain models, cycle math, prediction engine, crypto, storage & sync *interfaces*. The future desktop shell (Phase 13) reuses this untouched. |
| [`app/`](./app) | `olf_app` | Flutter app (iOS + Android). UI and platform glue. Depends on `olf_core` via `path: ../core`. |

## Toolchain

SDK is pinned in [`mise.toml`](./mise.toml): **Flutter 3.35.5 / Dart 3.9.2**.

```sh
mise install                       # one-time: install the pinned toolchain
mise exec -- flutter --version     # or `mise activate` to drop the prefix
```

## Common commands

```sh
# core (pure Dart)
cd core && mise exec -- dart pub get && mise exec -- dart test

# app (Flutter)
cd app && mise exec -- flutter pub get && mise exec -- flutter test
mise exec -- flutter run            # needs a connected device / emulator / simulator

# whole repo
mise exec -- dart format core app
```

CI (`.github/workflows/ci.yml`) runs format, analyze, test, dependency-audit and build on every
PR into `main`. Pushing a `vX.Y.Z` tag runs `.github/workflows/release.yml`, which builds a
signed Android APK and attaches it to a GitHub Release.

## Install (Android)

Grab `app-release.apk` from the [Releases page](https://github.com/Abbo0dio/olf/releases). It is
a **signed release build** produced by CI from a tagged commit. To sideload: enable "install
unknown apps" for your browser or file manager, open the APK, and confirm.

iOS builds are not distributed this way yet — Apple code signing / TestFlight is future work.

## License

[GNU General Public License v3.0](./LICENSE). Forks and derivatives must stay open source under
the same terms — a period tracker's privacy promise is only as good as its auditable source.
