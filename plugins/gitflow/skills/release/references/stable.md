# Stable Release Procedure

## Prerequisites

- All changes merged to `main` via PR from `develop`
- CI passing on `main`
- Quality gate passes locally

## Steps

### 1. Pre-Release Checks

```bash
git checkout main
git pull
# Run your project's quality gate
make check
```

All gates must pass: build zero errors, lint zero errors, format clean, all tests pass.

### 2. Create Release Tag

```bash
git tag -a "v{VERSION}" -m "Release v{VERSION}"
git push origin v{VERSION}
```

This triggers the CI release workflow. **Never tag without the quality gate passing first.**

### 3. Monitor Automated Release

```bash
gh run list --workflow=release.yml --limit 1
gh run watch <run-id>
```

### 4. Verify Release

```bash
gh release view v{VERSION}
# Should show: correct title, assets attached, NOT pre-release
```

### 5. Forward-Port Auto-Generated Files to Develop — MANDATORY

If your CI writes files directly to `main` after a release (e.g., an appcast or changelog update workflow), those changes are never automatically forward-ported. After verifying the release, sync them back to `develop`:

```bash
git checkout -b fix/sync-release-v{VERSION} develop
git checkout origin/main -- Docs/appcast.xml Docs/appcast-beta.xml  # adjust paths as needed
git commit -m "chore: Sync auto-generated release files for v{VERSION} back to develop"
git push -u origin fix/sync-release-v{VERSION}
gh pr create --base develop --title "chore: Sync release files for v{VERSION} back to develop"
```

Merge once CI passes. Skipping this creates conflicts on the next develop → main promotion.

## Troubleshooting

**Release workflow fails on CI check:** The commit must have a passing CI run.

```bash
git log -1 --format="%H"
gh run list --commit <sha> --workflow=ci.yml
```

Fix the issue on `main`, wait for CI, delete the failed tag, re-tag.

**Delete and re-tag:**

```bash
gh release delete v{VERSION} --yes
git tag -d v{VERSION}
git push origin :refs/tags/v{VERSION}
# Then re-tag once the fix is in place
```

## What NOT to Do

- NEVER create releases manually with `gh release create`
- NEVER tag without running the quality gate first
- NEVER tag from branches other than `main`
- NEVER skip CI verification
