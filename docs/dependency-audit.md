# Dependency audit

`requirements.md` §3 is a hard architectural constraint: **zero third-party advertising or
analytics SDKs, ever** — transitively included. Embedding SDKs that can see health data is a
direct legal-liability vector (Flo/FTC 2021; the 2025 Meta/CIPA verdict). The dependency-audit
CI gate enforces this mechanically. It is a **release blocker** (`DEVELOPMENT_PLAN.md` p2.9).

## What runs

- **Script:** [`.github/scripts/dependency_audit.dart`](../.github/scripts/dependency_audit.dart)
  — pure `dart:` libraries, no `pub get` needed to run it.
- **CI job:** `dependency-audit` in [`.github/workflows/ci.yml`](../.github/workflows/ci.yml),
  part of the required `CI OK` aggregate check.
- **Denylist:** [`.github/dependency-denylist.txt`](../.github/dependency-denylist.txt).
- **Regression test:** [`core/test/dependency_audit_test.dart`](../core/test/dependency_audit_test.dart)
  runs the script against deliberately-failing fixtures and asserts it exits non-zero.

## The two rules

### 1. No denylisted package in the locked graph

The job runs `pub get` for `core` and `app`, fails if either committed `pubspec.lock` is now
stale (so the audit always sees the real graph), then scans **every** package in both lock
files — `direct main`, `direct dev`, and `transitive` alike — against the denylist. Any match
fails the build.

### 2. No un-audited Android permission

The app's **main** manifest (`app/android/app/src/main/AndroidManifest.xml`) is scanned for
`<uses-permission>` entries. Each must be immediately preceded (within a few lines) by an
`audited:` justification comment, e.g.:

```xml
<!-- audited: required for encrypted backup export to a user-chosen file (p1.10);
     no telemetry. Reviewed 2026-08-27 by <reviewer>. -->
<uses-permission android:name="android.permission.INTERNET"/>
```

Flutter's generated `src/debug` and `src/profile` manifests (which add `INTERNET` for hot
reload / DevTools) are **not** scanned — they are tooling-managed and never ship in a release
build. Review them by eye if they ever change.

iOS App Transport Security / URL-scheme review is manual for now; it becomes a gate in **p2.6**.

## Denylist file format

One rule per line; `#` starts a comment. Every entry must carry a one-line rationale.

| Form | Meaning | Example |
|------|---------|---------|
| `package_name` | exact pub package-name match | `firebase_analytics` |
| `~fragment` | case-insensitive substring match (vendor families) | `~appsflyer` |
| `re:pattern` | case-insensitive regular-expression match | `re:^unity_ads` |

Prefer exact names. Use `~` / `re:` only for a vendor that ships many packages, and keep the
fragment specific enough that it cannot match an unrelated package.

## Adding an entry

1. Add the line to `.github/dependency-denylist.txt` with a rationale comment.
2. If you are adding it because a real dependency pulled it in, also remove that dependency in
   the same PR — a denylist entry is not a substitute for fixing the graph.
3. Note it in the PR description. Adding entries is routine; **removing** one needs an explicit
   reviewer sign-off in the PR.

## Running it locally

```sh
mise exec -- dart .github/scripts/dependency_audit.dart \
  --denylist .github/dependency-denylist.txt \
  --lock core/pubspec.lock --lock app/pubspec.lock \
  --manifest app/android/app/src/main/AndroidManifest.xml

# and the fixture-backed tests
cd core && mise exec -- dart test test/dependency_audit_test.dart
```

Exit codes: `0` clean · `1` violation(s) · `2` bad invocation / missing input.

## What the audit does NOT catch

- SDKs added via native Gradle/CocoaPods directly (not through a pub package). Phase 2's threat
  model (p2.8) and release review cover this; revisit if we ever add native deps.
- Behavioural exfiltration by an otherwise-allowlisted package. That is a code-review and
  threat-model concern, not a name check.
