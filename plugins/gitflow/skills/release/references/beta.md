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

Once testing is complete, follow the [stable release procedure](stable.md) in full.

**NEVER promote by opening `develop → main` directly.** Always cut a `release/vX.Y.Z` branch
first — see `stable.md` for the reasons and exact steps.

The short version:

```bash
git checkout -b release/v0.7.0 develop
# Update CHANGELOG, push
gh pr create --base main --head release/v0.7.0 --title "release: v0.7.0"
# After merge: tag on main, back-merge release branch to develop
```

## Version Progression

```
v1.0.0-alpha.1  →  v1.0.0-alpha.2  →  v1.0.0-beta.1  →  v1.0.0-beta.2  →  v1.0.0-rc.1  →  v1.0.0
```

## What NOT to Do

- NEVER create beta releases without the suffix in the tag
- NEVER mark stable releases as pre-release
- NEVER promote beta to stable without testing
- NEVER open `develop → main` directly for promotion — always use a release branch
