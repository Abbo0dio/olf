# Dependency audit

`requirements.md` §3 is a hard architectural constraint: **zero third-party advertising or
analytics SDKs, ever** — transitively included. Embedding SDKs that can see health data is a
direct legal-liability vector (Flo/FTC 2021; the 2025 Meta/CIPA verdict). The dependency-audit
CI gate enforces this mechanically. It is a **release blocker** (`DEVELOPMENT_PLAN.md` p2.9).

## Release blocker (p2.9)

A red dependency audit **blocks the release**. It is un-waivable by design:

- The script has **no `--skip` / `--force` / `--allow` flag** and reads **no environment
  variable** that could bypass it. Any non-zero exit fails the job.
- The `dependency-audit` job carries **no `continue-on-error`** and is gated only by
  `detect` (the workspace probe).
- The `CI OK` aggregate requires the `dependency-audit` job result to be exactly
  `success`. A **skipped** audit (e.g. someone removes the Flutter workspace or the job's
  `if:` guard) is treated as a **failure**, not a pass.
- The canonical audit arguments in `ci.yml` are **locked by
  `core/test/dependency_audit_test.dart`** — dropping a `--lock`, `--manifest`,
  `--net-config` or `--plist`, or pointing `--denylist` at a stub, fails the test job.

### Escalation path — a package genuinely trips a rule

**Who decides:** the change needs sign-off from whoever holds the **security-reviewer**
role for the release (recorded in the PR; for a solo maintainer this is an explicit,
written self-review in the PR description — see `release-checklist.md`).

1. **A real ad / analytics / tracking package is in the graph.** Not a waiver case — the
   gate is correct. Find the dependency that pulls it in
   (`dart pub deps -s list` / `flutter pub deps -s list`) and **remove or replace it**, or
   drop the feature that needs it. Ship the PR with the graph clean.
2. **False positive** — an over-broad `~fragment` / `re:pattern` rule matched a package
   that genuinely has **no** ad/analytics/tracking capability. The security reviewer
   **narrows that specific rule** in `.github/dependency-denylist.txt` so it no longer
   matches the innocent package, **in the same PR**, with a rationale comment and recorded
   sign-off. Never a blanket carve-out, never a new allowlist.
3. **Removing a denylist entry** (rules 1 or 2 aside) always needs explicit
   security-reviewer sign-off in the PR — see [Adding an entry](#adding-an-entry).

There is deliberately no fourth option. If a genuinely needed package carries tracking
capability, the answer is to not ship that package.

## What runs

- **Script:** [`.github/scripts/dependency_audit.dart`](../.github/scripts/dependency_audit.dart)
  — pure `dart:` libraries, no `pub get` needed to run it.
- **CI job:** `dependency-audit` in [`.github/workflows/ci.yml`](../.github/workflows/ci.yml),
  part of the required `CI OK` aggregate check.
- **Denylist:** [`.github/dependency-denylist.txt`](../.github/dependency-denylist.txt).
- **Regression test:** [`core/test/dependency_audit_test.dart`](../core/test/dependency_audit_test.dart)
  runs the script against deliberately-failing fixtures and asserts it exits non-zero.

## The rules

### 1. No denylisted package in the locked graph

The job runs `pub get` for `core` and `app`, fails if either committed `pubspec.lock` is now
stale (so the audit always sees the real graph), then scans **every** package in both lock
files — `direct main`, `direct dev`, and `transitive` alike — against the denylist. Any match
fails the build.

### 2. No un-audited Android permission (and no manifest cleartext)

The app's **main** manifest (`app/android/app/src/main/AndroidManifest.xml`) is scanned for
`<uses-permission>` entries. Each must be immediately preceded (within a few lines) by an
`audited:` justification comment, e.g.:

```xml
<!-- audited: required for encrypted backup export to a user-chosen file (p1.10);
     no telemetry. Reviewed 2026-08-27 by <reviewer>. -->
<uses-permission android:name="android.permission.INTERNET"/>
```

The same scan fails on `android:usesCleartextTraffic="true"` anywhere in that manifest (p2.6).

Flutter's generated `src/debug` and `src/profile` manifests (which add `INTERNET` for hot
reload / DevTools) are **not** scanned — they are tooling-managed and never ship in a release
build. Review them by eye if they ever change.

### 3. Transport security baseline (p2.6)

`--net-config app/android/app/src/main/res/xml/network_security_config.xml` and
`--plist app/ios/Runner/Info.plist` are scanned (XML/plist comments stripped first, so a
warning comment naming a token does not trip it). The build fails if:

- the network-security config says `cleartextTrafficPermitted="true"`, is missing the explicit
  `"false"`, or contains a `<debug-overrides>` block;
- the Info.plist sets any `NSAllowsArbitraryLoads*` / `NSAllowsLocalNetworking` to `<true/>`,
  or declares `NSExceptionDomains`.

Full rationale and the Dart `OlfHttpClient` seam: [`transport-security.md`](transport-security.md).

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
  --manifest app/android/app/src/main/AndroidManifest.xml \
  --net-config app/android/app/src/main/res/xml/network_security_config.xml \
  --plist app/ios/Runner/Info.plist

# and the fixture-backed tests
cd core && mise exec -- dart test test/dependency_audit_test.dart
```

Exit codes: `0` clean · `1` violation(s) · `2` bad invocation / missing input. In CI **any**
non-zero exit fails the job, and a bad invocation (exit `2`) is a failure too — it means the
gate did not actually run.

## What the audit does NOT catch

- SDKs added via native Gradle/CocoaPods directly (not through a pub package). Phase 2's threat
  model (p2.8) and release review cover this; revisit if we ever add native deps.
- Behavioural exfiltration by an otherwise-allowlisted package. That is a code-review and
  threat-model concern, not a name check.
