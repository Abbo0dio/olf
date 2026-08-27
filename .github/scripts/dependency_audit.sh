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
#   - Greps each package's pubspec.yaml (and pubspec.lock when present — it is
#     gitignored, so usually only after `pub get`) for denylisted names.
#   - Only WARNS on a match. p0.3 makes matches fatal and adds the committed
#     denylist file, the extension docs, and a deliberately-failing fixture.
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

# Manifests to scan. pubspec.lock is added when it exists (transitive coverage).
FILES=()
for f in core/pubspec.yaml app/pubspec.yaml core/pubspec.lock app/pubspec.lock; do
  [ -f "$f" ] && FILES+=("$f")
done

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "No pubspec manifests found. Nothing to audit. PASS (stub)."
  exit 0
fi

echo "Scanning ${FILES[*]} against ${#DENYLIST[@]} denylisted package names..."
hits=0
for pkg in "${DENYLIST[@]}"; do
  if grep -Eqs "(^|[[:space:]\"'])${pkg}:" "${FILES[@]}"; then
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
