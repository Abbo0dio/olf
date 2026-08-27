#!/usr/bin/env bash
# Dependency audit — Phase 0 STUB.
#
# Purpose (final form, delivered in p0.3):
#   Fail the build if any dependency (transitive included) matches a denylist of
#   advertising / analytics / tracking SDKs, or if a new network permission is
#   added to a native manifest without an adjacent `// audited: <reason>` note.
#   requirements.md §3: "Zero third-party advertising or analytics SDKs."
#   DEVELOPMENT_PLAN.md §1.4 and p0.3.
#
# This stub:
#   - Documents intent so the CI job exists and is valid now.
#   - Does a best-effort grep against pubspec.lock IF it exists (it will not until
#     p0.2). It only WARNS on a match; p0.3 makes matches fatal and adds the
#     committed denylist file, the extension docs, and a failing-fixture test.
#
# Exit non-zero only on an internal error, never (yet) on a denylist hit.

set -euo pipefail

echo "== dependency audit (Phase 0 stub) =="

# Seed denylist. p0.3 moves this to a committed, documented file with rationale
# per entry and a documented process for extending it.
DENYLIST=(
  # Analytics / product analytics
  firebase_analytics google_analytics amplitude mixpanel segment posthog
  heap countly matomo
  # Crash/plugin SDKs that phone home by default
  firebase_crashlytics sentry_flutter bugsnag instabug
  # Advertising / attribution
  google_mobile_ads applovin_max facebook_audience_network unity_ads
  appsflyer_sdk adjust_sdk branch_sdk singular_flutter_sdk
  facebook_app_events app_tracking_transparency
)

LOCKFILE="pubspec.lock"
if [ ! -f "$LOCKFILE" ]; then
  echo "No $LOCKFILE yet (Flutter workspace arrives in p0.2)."
  echo "Nothing to audit. PASS (stub)."
  exit 0
fi

echo "Scanning $LOCKFILE against ${#DENYLIST[@]} denylisted package names..."
hits=0
for pkg in "${DENYLIST[@]}"; do
  if grep -Eq "^\s{2}${pkg}:" "$LOCKFILE"; then
    echo "::warning::denylisted dependency present: ${pkg} (p0.3 will make this fatal)"
    hits=$((hits + 1))
  fi
done

if [ "$hits" -gt 0 ]; then
  echo "$hits denylisted dependency name(s) matched. Not failing yet (stub); p0.3 will."
else
  echo "No denylisted dependency names matched."
fi

echo "PASS (stub)."
exit 0
