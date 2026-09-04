#!/usr/bin/env bash
set -euo pipefail

# Cuts an olf release: opens a PR for the release-prep commit already sitting
# on the current branch, waits for CI, squash-merges it, tags the merged
# commit, and pushes the tag — which triggers .github/workflows/release.yml
# to build the SIGNED release APK and publish it to a new GitHub Release.
#
# This script does NOT decide the version number or bump pubspec.yaml for
# you — that is a manual call per the versioning policy in
# DEVELOPMENT_PLAN.md §7 (2026-09-04 entry): `1.x.x` is the alpha stage until
# every phase is DONE, `2.0.0` is the beta cut the moment the last phase
# closes; inside `1.x`, a minor bump means new features shipped since the
# last release, a patch bump means bug-fixes-only. Decide the number, bump
# `app/pubspec.yaml` `version:` yourself (and make any other release-prep
# edits), commit them on a branch, THEN run this script from that branch.
#
# Run docs/release-checklist.md's Blockers + Checks BEFORE this script —
# it does not run them for you.
#
# Usage, from the repo root, on the release-prep branch with everything
# already committed:
#   scripts/cut_release.sh
#
# Requires: gh (authenticated), a clean working tree, HEAD's app/pubspec.yaml
# version matching what you intend to tag.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree is not clean — commit your release-prep changes first" >&2
  exit 1
fi

branch="$(git branch --show-current)"
if [[ -z "$branch" || "$branch" == "main" ]]; then
  echo "error: run this from the release-prep branch, not main (detached HEAD or main is not a release-prep branch)" >&2
  exit 1
fi

version="$(grep '^version:' app/pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: could not parse a semver version out of app/pubspec.yaml (got '$version')" >&2
  exit 1
fi
tag="v${version}"

if git rev-parse "$tag" >/dev/null 2>&1; then
  echo "error: tag $tag already exists locally" >&2
  exit 1
fi
if git ls-remote --tags origin "refs/tags/$tag" | grep -q "$tag"; then
  echo "error: tag $tag already exists on origin" >&2
  exit 1
fi

echo "== Releasing $tag from branch $branch =="

echo "-- pushing branch --"
git push -u origin "$branch"

echo "-- opening PR (or reusing one already open for this branch) --"
pr_number="$(gh pr view "$branch" --json number -q .number 2>/dev/null || true)"
if [[ -z "$pr_number" ]]; then
  pr_url="$(gh pr create \
    --title "chore: release ${tag}" \
    --body "Release-prep commit for ${tag}. See docs/release-checklist.md and DEVELOPMENT_PLAN.md §7 (versioning policy)." \
    --base main)"
  pr_number="${pr_url##*/}"
  echo "PR #${pr_number}: ${pr_url}"
else
  echo "reusing existing PR #${pr_number}"
fi

echo "-- waiting for checks to register on PR #${pr_number} --"
appeared=false
for _ in $(seq 1 12); do
  count="$(gh pr checks "$pr_number" --json name -q 'length' 2>/dev/null || echo 0)"
  if [[ "${count:-0}" -gt 0 ]]; then
    appeared=true
    break
  fi
  sleep 5
done
if [[ "$appeared" != true ]]; then
  echo "error: no CI checks appeared on PR #${pr_number} after 60s" >&2
  exit 1
fi

echo "-- waiting for CI (this blocks until every check finishes) --"
gh pr checks "$pr_number" --watch

echo "-- CI green, merging --"
gh pr merge "$pr_number" --squash

echo "-- syncing local main --"
git checkout main
git fetch origin --quiet
git pull --ff-only origin main --quiet
release_sha="$(git rev-parse HEAD)"
echo "main is now at $release_sha"

echo "-- tagging $tag --"
git tag "$tag" "$release_sha"
git push origin "$tag"

echo "-- tag pushed, waiting for the Release workflow to start --"
sleep 10
run_id=""
for _ in $(seq 1 12); do
  run_id="$(gh run list --workflow=release.yml --branch "$tag" --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)"
  [[ -n "$run_id" ]] && break
  sleep 5
done

if [[ -z "$run_id" ]]; then
  echo "warning: could not find the Release workflow run — check manually: gh run list --workflow=release.yml" >&2
  exit 0
fi

echo "-- watching run $run_id --"
gh run watch "$run_id" --exit-status

echo "-- done — verifying the release --"
gh release view "$tag"
