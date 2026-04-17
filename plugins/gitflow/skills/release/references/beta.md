# Beta Release Procedure

Beta releases are pre-releases for testing before stable promotion.

## Tag Naming

Beta tags MUST include a pre-release suffix:

```
v0.7.0-beta.1    v0.7.0-beta.2    v1.0.0-alpha.1    v1.0.0-rc.1
```

Suffixes: `-beta`, `-alpha`, `-rc`, `-dev`

GitHub detects these as pre-releases automatically based on the suffix.

## Steps

### 1. Ensure Changes Are on Develop

```bash
git checkout develop
git pull
```

### 2. Create Beta Tag

```bash
git tag -a "v0.7.0-beta.1" -m "Release v0.7.0-beta.1"
git push origin v0.7.0-beta.1
```

### 3. Monitor

```bash
gh run list --workflow=release.yml --limit 1
gh run watch <run-id>
gh release view v0.7.0-beta.1
# Should be marked as pre-release
```

## Promoting Beta to Stable

Once testing is complete, open a PR to promote `develop` → `main`:

```bash
gh pr create --base main --head develop --title "release: v0.7.0" \
  --body "Promotes develop to main for stable release v0.7.0"
```

Wait for CI to pass on the merge commit, then merge. After merge:

```bash
git checkout main
git pull
git tag -a "v0.7.0" -m "Release v0.7.0"
git push origin v0.7.0
```

The stable release requires CI to pass and marks as latest (not pre-release).

## Version Progression

```
v1.0.0-alpha.1  →  v1.0.0-alpha.2  →  v1.0.0-beta.1  →  v1.0.0-beta.2  →  v1.0.0-rc.1  →  v1.0.0
```

## What NOT to Do

- NEVER create beta releases without the suffix in the tag
- NEVER mark stable releases as pre-release
- NEVER promote beta to stable without testing
