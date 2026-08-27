# Branch protection — `main`

`main` is protected by a **repository ruleset** named **`protect-main`**
(`enforcement: active`). This file documents what is configured, how to verify it, and how to
change it. It is descriptive — the ruleset on GitHub is the source of truth.

Last confirmed: **2026-08-27** (updated during p0.3 — added required status check).

## What is enforced

| Rule | Setting | Effect |
|------|---------|--------|
| Pull request required | `required_approving_review_count: 0` | No commits may be pushed straight to `main`; changes must go through a PR. Zero approvals are *required* today, but review is still a workflow rule (CONTRIBUTING.md §3.6) — raise this number once there is more than one regular contributor. |
| Required status checks | `CI OK` | A PR cannot merge unless the `CI OK` check (the aggregate job in `.github/workflows/ci.yml`) has succeeded on the PR head. `CI OK` fails if any of format / analyze / test / dependency-audit / build failed or was cancelled; it stays green when those legitimately skip. `strict_required_status_checks_policy: false` — a PR need not be rebased on the latest `main` first. |
| Allowed merge methods | `squash` only | Merge commits and rebase-merges are disabled. One squashed commit per PR lands on `main`. |
| Required linear history | on | No merge commits on `main`. |
| Block force pushes | on (`non_fast_forward`) | History on `main` cannot be rewritten. |
| Block deletions | on (`deletion`) | `main` cannot be deleted. |
| Dismiss stale reviews on push | on | New commits invalidate prior approvals. |
| Extra approval for unattributed changes | on | Commits whose author is not a verified collaborator need an additional approval. |
| Bypass actors | none | Nobody (including admins) can bypass; `current_user_can_bypass: never`. |

## What is NOT enforced

- **Approvals:** `required_approving_review_count` is `0` — review is a workflow convention
  (CONTRIBUTING.md §3.6), not yet mechanically required. Raise to `1` once a second regular
  contributor joins.
- **Up-to-date branch before merge:** `strict_required_status_checks_policy` is `false`, so CI
  passing on a slightly stale branch is accepted. Turn on if a race ever lands a broken `main`.

## How to verify

```sh
# List rulesets
gh api repos/Abbo0dio/olf/rulesets

# Full detail of this ruleset
gh api repos/Abbo0dio/olf/rulesets/21675040

# Prove direct pushes are blocked (run from a clean throwaway clone/branch)
git commit --allow-empty -m "should be rejected" && git push origin HEAD:main
#  -> remote rejects with "Changes must be made through a pull request."
```

## How to change it

1. Propose the change in a PR that edits **this file** (and, if relevant, CONTRIBUTING.md §6),
   so the rationale is in history.
2. Apply it via the GitHub UI (**Settings → Rules → Rulesets → protect-main**) or the API:

   ```sh
   gh api -X PUT repos/Abbo0dio/olf/rulesets/21675040 \
     --input updated-ruleset.json
   ```

3. Update the "Last confirmed" date and the table above in the same PR.

The `required_status_checks` rule was added in p0.3 with:

```jsonc
{
  "type": "required_status_checks",
  "parameters": {
    "strict_required_status_checks_policy": false,
    "do_not_enforce_on_create": false,
    "required_status_checks": [{ "context": "CI OK" }]
  }
}
```

Common near-term changes:

- Add `required_approving_review_count: 1` when a second regular contributor joins.
- Flip `strict_required_status_checks_policy` to `true` if merge races become a problem.
