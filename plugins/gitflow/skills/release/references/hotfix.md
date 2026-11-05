# Hotfix Release Procedure

Use for critical production bugs, security vulnerabilities, or data loss issues that cannot wait for a normal release cycle.

**NEVER bypass the automated release system. If automation fails, fix the automation.**

## Prerequisites

- You know the base version being hotfixed (e.g., v0.6.3)
- The bug is confirmed in production and cannot wait for `develop` to be promoted
- A fix is ready to implement (or already written and tested locally)

## Steps

### 1. Create Hotfix Branch from the Release Tag

```bash
git checkout -b hotfix/v0.6.4 v0.6.3
```

### 2. Implement the Fix

Apply the fix directly on the hotfix branch. Keep it minimal — only the targeted change.

```bash
git add <files>
git commit -m "fix: <Description>"
git push -u origin hotfix/v0.6.4
```

### 3. Open the Hotfix PR into Main

```bash
gh pr create --base main --head hotfix/v0.6.4 \
  --title "fix: <Description>" \
  --body "Hotfix v0.6.4: <what broke and how this fixes it>."
```

### 4. Wait for CI, then Merge with --merge

**MANDATORY before merging.** CI must pass on the PR.

```bash
gh pr checks --watch
gh pr merge --merge   # never --squash: the tag must point at main's history
```

### 5. Tag the Merge Commit on Main

The tag goes on `main`, never on the hotfix branch: every released tag sits on `main`.

```bash
git checkout main && git pull origin main
git tag -a "v0.6.4" -m "Release v0.6.4"
git push origin v0.6.4
```

### 6. Monitor Automated Release, then Clean Up

```bash
gh run list --workflow=release.yml --limit 1
gh run watch <run-id>
gh release view v0.6.4
git push origin --delete hotfix/v0.6.4
git branch -d hotfix/v0.6.4
```

### 7. Forward-Port to Develop — MANDATORY

**This step is not optional.** The hotfix is now on `main`; it MUST also land on `develop`. Skipping this causes divergence that creates merge conflicts on the next `release/vX.Y.Z` → main PR.

After the release is confirmed, open a PR to bring the fix to `develop`:

```bash
git checkout -b fix/forward-port-v0.6.4 develop
git cherry-pick <fix-commit-sha>
git push -u origin fix/forward-port-v0.6.4
gh pr create --base develop --title "fix: Forward-port hotfix v0.6.4" \
  --body "Cherry-picks the v0.6.4 hotfix commit onto develop."
```

Merge once CI passes. If the cherry-pick has conflicts (develop has diverged significantly), resolve them before pushing.

**Auto-generated files (appcasts, changelogs):** If your CI writes files directly to `main` after a release (e.g., an `update-appcast` workflow), those changes are never automatically forward-ported. Include them in your forward-port PR by running:

```bash
git checkout origin/main -- Docs/appcast.xml Docs/appcast-beta.xml
```

## What NOT to Do

- NEVER create releases manually with `gh release create`
- NEVER bypass CI verification
- NEVER tag the hotfix branch: tag the merge commit on `main`
- NEVER commit to `main` directly: the hotfix arrives by PR
- NEVER work around failed automation — fix it instead
- NEVER skip step 7 — every main change must flow back to develop
