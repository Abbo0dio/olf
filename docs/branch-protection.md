# Branch protection — `main`

`main` is protected by a **repository ruleset** named **`protect-main`**
(`enforcement: active`). This file documents what is configured, how to verify it, and how to
change it. It is descriptive — the ruleset on GitHub is the source of truth.

Last confirmed: **2026-08-27** (during p0.1).

## What is enforced

| Rule | Setting | Effect |
|------|---------|--------|
| Pull request required | `required_approving_review_count: 0` | No commits may be pushed straight to `main`; changes must go through a PR. Zero approvals are *required* today, but review is still a workflow rule (CONTRIBUTING.md §3.6) — raise this number once there is more than one regular contributor. |
| Allowed merge methods | `squash` only | Merge commits and rebase-merges are disabled. One squashed commit per PR lands on `main`. |
| Required linear history | on | No merge commits on `main`. |
| Block force pushes | on (`non_fast_forward`) | History on `main` cannot be rewritten. |
| Block deletions | on (`deletion`) | `main` cannot be deleted. |
| Dismiss stale reviews on push | on | New commits invalidate prior approvals. |
| Extra approval for unattributed changes | on | Commits whose author is not a verified collaborator need an additional approval. |
| Bypass actors | none | Nobody (including admins) can bypass; `current_user_can_bypass: never`. |

## What is NOT enforced yet

- **No required status checks.** CI (`.github/workflows/ci.yml`) runs on every PR, but the
  ruleset does not yet block merging on a failing or missing run. This is wired in **p0.3**,
  which adds a `required_status_checks` rule pointing at the CI aggregate check (`CI OK`).
  Until then, a PR into `main` is technically mergeable without a green CI run — treat green
  CI as mandatory by convention.

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

Common near-term changes:

- **p0.3** — add `required_status_checks` for the `CI OK` check.
- Add `required_approving_review_count: 1` when a second regular contributor joins.
