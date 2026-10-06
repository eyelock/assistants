# Setting Up Gitflow in a New Project

How to adopt the develop/main branching model from scratch or migrate from a single-branch workflow.

## What You're Setting Up

```
main       ← stable, production-ready. Only receives PRs from release/* or hotfix/* branches.
develop    ← integration branch. All feature/fix work merges here first.
feat/*     ← short-lived feature branches (also fix/*, docs/*, ...), created from develop.
release/*  ← release/vX.Y.Z, cut from develop and PR'd into main to ship a stable release.
hotfix/*   ← hotfix/vX.Y.Z, emergency patches, created from a release tag.
```

## Step 1: Create the Develop Branch

If the repo only has `main`:

```bash
git checkout main
git pull
git checkout -b develop
git push -u origin develop
```

## Step 2: Set Default Branch

In GitHub, go to **Settings → Branches → Default branch** and change it to `develop`. This ensures new PRs target `develop` by default.

## Step 3: Configure Branch Protection

In GitHub, go to **Settings → Branches → Branch protection rules**. Add rules for both `main` and `develop`:

**For `main`:**
- Require a pull request before merging
- Require status checks to pass (add your CI workflow)
- Require branches to be up to date before merging
- Do not allow force pushes
- Do not allow deletions

**For `develop`:**
- Same as main — this prevents accidental direct commits

## Step 4: Configure CI

Ensure your CI workflow runs on both branches and on PRs targeting them:

```yaml
on:
  push:
    branches: [main, develop, 'hotfix/**', 'release/**']
  pull_request:
    branches: [main, develop, 'hotfix/**', 'release/**']
```

## Step 5: Configure Merge Methods

In GitHub, go to **Settings → General → Pull Requests**. Enable **Allow squash merging** and **Allow merge commits**; disable **Allow rebase merging**. Feature/fix PRs into `develop` are squash-merged, which keeps `develop` history linear. `release/*` and `hotfix/*` PRs into `main` must use a true merge (`gh pr merge --merge`) to keep ancestry, so merge commits must stay enabled.

## Step 6: Update CLAUDE.md

Document the branch model so collaborators and AI assistants know the rules:

```markdown
## Branching

All feature work branches from `develop` and PRs back to `develop`.
Stable release: cut `release/vX.Y.Z` from `develop`, PR it into `main` (merge with `--merge`), then tag.
`develop` never opens a PR into `main` directly.
Never commit directly to `main` or `develop`.
```

## Step 7: Migrate In-Flight Work

If there are open PRs targeting `main`, update their base to `develop`:

```bash
gh pr edit <number> --base develop
```

## Day-to-Day Operation

Once set up, follow the `branching` skill for day-to-day operation.
