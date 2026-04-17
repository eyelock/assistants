# Setting Up Gitflow in a New Project

How to adopt the develop/main branching model from scratch or migrate from a single-branch workflow.

## What You're Setting Up

```
main      ← stable, production-ready. Only receives PRs from develop or hotfix branches.
develop   ← integration branch. All feature/fix work merges here first.
feat-*    ← short-lived feature branches, created from develop.
hotfix/*  ← emergency patches, created from a release tag.
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
    branches: [main, develop]
  pull_request:
    branches: [main, develop, 'hotfix/**']
```

## Step 5: Configure Squash Merge

In GitHub, go to **Settings → General → Pull Requests**. Enable only **Allow squash merging** (disable merge commits and rebase merging). This keeps `develop` history linear.

## Step 6: Update CLAUDE.md

Document the branch model so collaborators and AI assistants know the rules:

```markdown
## Branching

All feature work branches from `develop` and PRs back to `develop`.
Release promotion: PR from `develop` → `main`, then tag.
Never commit directly to `main` or `develop`.
```

## Step 7: Migrate In-Flight Work

If there are open PRs targeting `main`, update their base to `develop`:

```bash
gh pr edit <number> --base develop
```

## Day-to-Day Operation

Once set up, follow the `branching` skill for day-to-day operation.
