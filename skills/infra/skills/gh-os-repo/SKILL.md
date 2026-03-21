---
name: gh-os-repo
description: Set up and harden a public GitHub repository — repo settings, security, branch protection, templates, CI, and dependabot.
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

## Step 3: Branch protection on main

Set up required status checks and conversation resolution:

```bash
gh api repos/{owner}/{repo}/branches/main/protection -X PUT \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Build", "Test", "Lint", "Format Check"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
EOF
```

Key settings:
- **strict: true** — branch must be up to date with main before merging
- **Required checks** — adapt the context names to match your CI job names
- **required_conversation_resolution** — all review threads must be resolved before merge
- **allow_force_pushes: false** — protects commit history
- **allow_deletions: false** — prevents accidental branch deletion
- **enforce_admins: false** — admins can bypass in emergencies (use sparingly)

### Repository ruleset (additional layer)

Create a ruleset for defense-in-depth:

```bash
gh api repos/{owner}/{repo}/rulesets -X POST \
  --input - <<'EOF'
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
    { "type": "non_fast_forward" },
    { "type": "deletion" },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
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
      "bypass_mode": "exempt"
    }
  ]
}
EOF
```

The "All Clear" context should be a final CI job that depends on all other checks — this way you only maintain one required check in the ruleset even as individual CI jobs change.

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
| `CODEOWNERS` | Replace `{owner}`, adjust paths to project structure |
| `ISSUE_TEMPLATE/bug_report.md` | Add project-specific environment fields |
| `ISSUE_TEMPLATE/feature_request.md` | Ready to use as-is |
| `ISSUE_TEMPLATE/infrastructure-change.md` | Ready to use as-is |
| `ISSUE_TEMPLATE/config.yml` | Replace `{owner}/{repo}` in discussions URL |
| `DISCUSSION_TEMPLATE/ideas.yml` | Update intro text for the project |
| `DISCUSSION_TEMPLATE/q-a.yml` | Update intro text for the project |
| `PULL_REQUEST_TEMPLATE.md` | Ready to use as-is |
| `dependabot.yml` | Uncomment and set language ecosystem |
| `BRANCH_PROTECTION.md` | Update CI check names to match actual workflow |

## Step 6: CI pipeline

Set up `.github/workflows/ci.yml`:

- Trigger on push to main and pull requests
- Jobs: build, test, lint, format check
- Add a final "All Clear" job that depends on all others (for the ruleset)

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
    runs-on: ubuntu-latest
    needs: [build, test, lint, format-check]
    steps:
      - run: echo "All checks passed"
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

# Branch protection
gh api repos/{owner}/{repo}/branches/main/protection

# Rulesets
gh api repos/{owner}/{repo}/rulesets

# License detected
gh repo view {owner}/{repo} --json licenseInfo

# Templates exist
ls .github/ISSUE_TEMPLATE/ .github/DISCUSSION_TEMPLATE/ .github/PULL_REQUEST_TEMPLATE.md .github/CODEOWNERS .github/dependabot.yml
```
