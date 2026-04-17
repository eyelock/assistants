---
name: ci
description: GitHub Actions workflows that implement the Gitflow model — CI gating, branch protection enforcement, and tag-triggered release.
---

# CI for Gitflow

Three workflows wire up Gitflow in GitHub Actions. See references for annotated examples:

- [ci.md](references/ci.md) — quality gate on every push and PR
- [protect-main.md](references/protect-main.md) — enforce that only `develop` and `hotfix/*` can PR into `main`
- [release.md](references/release.md) — tag-triggered release with CI verification gate

## Branch Protection Settings

In **Settings → Branches**, configure rules for both `main` and `develop`:

- Require a pull request before merging
- Require status checks — add the **All Clear** job (see ci.md)
- Require branches to be up to date before merging
- Do not allow force pushes or deletions

Only the **All Clear** aggregator job should be a required check, not individual jobs. Individual jobs are skipped when irrelevant files change; the aggregator always runs and reports the true final status.

## Required Secrets

| Secret | Used by | Purpose |
|---|---|---|
| `GITHUB_TOKEN` | All workflows | Auto-provided; no setup needed |
| Any release secrets | `release.yml` | Project-specific (signing keys, credentials, registry tokens) |
