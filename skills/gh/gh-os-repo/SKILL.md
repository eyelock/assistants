---
name: gh-os-repo
description: Set up and manage an open source GitHub repository — license, contributing guide, CI, and releases.
---

# Open Source Repository Setup

You help set up a GitHub repository for open source distribution. Follow these steps to ensure the repo has everything contributors and users need.

## Step 1: Essential files

Create or verify these files exist at the repo root:

- **LICENSE** — Ask which license (MIT, Apache-2.0, BSD-3-Clause). Default to MIT if unsure.
- **README.md** — Project name, one-line description, install instructions, usage example, license badge.
- **CONTRIBUTING.md** — How to contribute: fork, branch, PR workflow. Mention code style, test expectations, and review process.
- **.gitignore** — Language-appropriate ignores.

## Step 2: GitHub community files

Create `.github/` directory with:

- **ISSUE_TEMPLATE/bug_report.md** — Steps to reproduce, expected vs actual, environment info.
- **ISSUE_TEMPLATE/feature_request.md** — Problem statement, proposed solution, alternatives.
- **PULL_REQUEST_TEMPLATE.md** — Summary, test plan, checklist (tests pass, docs updated, breaking changes noted).

## Step 3: CI pipeline

Set up `.github/workflows/ci.yml`:

- Trigger on push to main and pull requests
- Steps: checkout, setup language, install deps, lint, test, build
- Keep it simple — one job is fine to start

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # ... language-specific steps
```

## Step 4: Release workflow (optional)

If the project uses semantic versioning, set up `.github/workflows/release.yml`:

- Trigger on tag push (`v*`)
- Build artifacts, create GitHub release with changelog

## Step 5: Repository settings

Remind the user to configure via GitHub UI or `gh` CLI:

- Branch protection on `main` (require PR reviews, status checks)
- Enable issues and discussions if appropriate
- Add relevant topics/tags for discoverability

## Step 6: Verify

- `gh repo view` to confirm visibility and description
- Check that CI runs on a test PR
- Verify LICENSE is detected correctly by GitHub
