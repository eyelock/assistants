---
name: gh-os-repo
description: Set up and harden a public GitHub repository — repo settings, security, branch protection with a ruleset, templates, CI, and dependabot.
---

# Open Source Repository Setup

You configure a GitHub repository for open source distribution. This is a comprehensive checklist covering repo settings, security hardening, branch protection, community templates, CI, and dependency management.

Template files are in `assets/.github/` — copy them into the target repo's `.github/` directory and customize placeholders (`{owner}`, `{repo}`) for the project.

## Step 1: Repository settings

Configure via `gh api`:

```bash
gh api repos/{owner}/{repo} -X PATCH \
  -f description="<project description>" \
  -F has_issues=true \
  -F has_discussions=true \
  -F has_wiki=false \
  -F has_projects=true \
  -F allow_squash_merge=true \
  -F allow_merge_commit=true \
  -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true \
  -F allow_auto_merge=false \
  -F web_commit_signoff_required=false \
  -f squash_merge_commit_title="COMMIT_OR_PR_TITLE" \
  -f squash_merge_commit_message="COMMIT_MESSAGES" \
  -f merge_commit_title="MERGE_MESSAGE" \
  -f merge_commit_message="PR_TITLE"
```

Key decisions:
- **Rebase merge disabled** — keeps merge history clean, avoids rewritten SHAs
- **Delete branch on merge enabled** — auto-cleanup after PR merge
- **Wiki disabled** — docs live in the repo or a docs site, not a wiki
- **Discussions enabled** — gives a place for Q&A and ideas without cluttering issues

Add topics for discoverability:

```bash
gh repo edit --add-topic "topic1,topic2,topic3"
```

## Step 2: Security settings

Enable all security features:

```bash
gh api repos/{owner}/{repo} -X PATCH \
  -f "security_and_analysis[dependabot_security_updates][status]=enabled" \
  -f "security_and_analysis[secret_scanning][status]=enabled" \
  -f "security_and_analysis[secret_scanning_push_protection][status]=enabled"
```

This ensures:
- **Dependabot security updates** — automatic PRs for vulnerable dependencies
- **Secret scanning** — alerts if secrets are committed
- **Push protection** — blocks pushes containing detected secrets

## Step 3: Protect main with a ruleset

Protect the default branch with one repository ruleset. It is the single source of truth: do not also add classic branch protection (`branches/main/protection`). With both active, a merge must satisfy both, so there are two lists of required checks to keep in step, and they drift. A ruleset is visible to contributors on a public repo, targets the default branch by name, and lists who can bypass it.

The ruleset requires one status check, **All Clear**: a final CI job that depends on all the others (Step 6). Make sure the CI workflow has that job before you create the ruleset; a required check that never reports blocks every PR.

```bash
gh api repos/{owner}/{repo}/rulesets -X POST \
  --input - <<'JSON'
{
  "name": "Main Branch Protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "do_not_enforce_on_create": false,
        "required_status_checks": [
          { "context": "All Clear" }
        ]
      }
    }
  ],
  "bypass_actors": [
    {
      "actor_id": 5,
      "actor_type": "RepositoryRole",
      "bypass_mode": "always"
    }
  ]
}
JSON
```

Key settings:
- **deletion / non_fast_forward** — the branch cannot be deleted or force-pushed
- **pull_request** — changes reach main only through a PR, and every review thread must be resolved before merge
- **strict_required_status_checks_policy: true** — the branch must be up to date with main before merging
- **All Clear as the only required check** — one check to maintain, even as individual CI jobs change
- **bypass_actors** — repository admins (role 5) can bypass in emergencies; use sparingly

If the repo already has classic branch protection on main, remove it once the ruleset is active, so the ruleset stays the only source:

```bash
gh api repos/{owner}/{repo}/branches/main/protection -X DELETE
```

## Step 4: Essential repo files

Create or verify these exist at the repo root:

- **LICENSE** — Default to MIT. Ask if Apache-2.0 or BSD-3-Clause preferred.
- **README.md** — Project name, description, install instructions, usage example, license badge.
- **CONTRIBUTING.md** — Fork, branch, PR workflow. Code style, test expectations, and review process.
- **.gitignore** — Language-appropriate ignores.

## Step 5: Community files from assets

Copy `assets/.github/` into the target repo and customize:

| Asset | Customize |
|-------|-----------|
| `CODEOWNERS` | Replace `{owner}` with the user's team or handle; keep the `*` default and replace the example paths with directories and files this repo has (`ls` it; `/src/` and `/tests/` are examples, a path that matches nothing is noise) |
| `ISSUE_TEMPLATE/bug_report.md` | Add project-specific environment fields |
| `ISSUE_TEMPLATE/feature_request.md` | Ready to use as-is |
| `ISSUE_TEMPLATE/infrastructure-change.md` | Ready to use as-is: copy it too, every template in the set belongs in the repo |
| `ISSUE_TEMPLATE/config.yml` | Replace `{owner}/{repo}` in discussions URL |
| `DISCUSSION_TEMPLATE/ideas.yml` | Update intro text for the project |
| `DISCUSSION_TEMPLATE/q-a.yml` | Update intro text for the project |
| `PULL_REQUEST_TEMPLATE.md` | Ready to use as-is |
| `dependabot.yml` | Uncomment and set language ecosystem |
| `BRANCH_PROTECTION.md` | Ready to use as-is if CI's aggregator job is named All Clear |

## Step 6: CI pipeline

Set up `.github/workflows/ci.yml`:

- Trigger on push to main and pull requests
- Jobs: build, test, lint, format check
- A final job named **All Clear** that depends on all others: the one check the ruleset requires

All Clear must run even when a job it needs fails (`if: always()`) and fail itself in that case. Without `if: always()` it is skipped when a dependency fails, and GitHub counts a skipped required check as passing, so the PR could merge red.

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # ... language-specific build steps

  # Repeat for test, lint, format-check

  all-clear:
    name: All Clear
    runs-on: ubuntu-latest
    needs: [build, test, lint, format-check]
    if: always()
    steps:
      - name: Check results
        run: |
          if [[ "${{ contains(needs.*.result, 'failure') }}" == "true" ]] || \
             [[ "${{ contains(needs.*.result, 'cancelled') }}" == "true" ]]; then
            echo "One or more checks failed"
            exit 1
          fi
          echo "All checks passed"
```

## Step 7: Release workflow (optional)

If the project uses semantic versioning, set up `.github/workflows/release.yml`:

- Trigger on tag push (`v*`)
- Build artifacts, create GitHub release with changelog

## Step 8: Verify

Run through this checklist:

```bash
# Repo settings
gh repo view {owner}/{repo} --json description,visibility,hasIssuesEnabled,hasDiscussionsEnabled,hasWikiEnabled

# Security
gh api repos/{owner}/{repo} --jq '.security_and_analysis'

# The ruleset, and the rules it enforces on main
gh api repos/{owner}/{repo}/rulesets
gh api repos/{owner}/{repo}/rules/branches/main

# License detected
gh repo view {owner}/{repo} --json licenseInfo

# Templates exist
ls .github/ISSUE_TEMPLATE/ .github/DISCUSSION_TEMPLATE/ .github/PULL_REQUEST_TEMPLATE.md .github/CODEOWNERS .github/dependabot.yml
```
