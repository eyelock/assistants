---
name: release
description: Tag-driven release automation - cutting a stable, beta or hotfix release, choosing the version bump, and monitoring the release workflow. Use to ship a release or when a release fails. Never create releases manually.
---

# Release Procedures

## Release System Overview

Releases are fully automated via CI. The workflow is:

1. Developer creates an annotated git tag
2. CI release workflow triggers, verifies, builds, and publishes
3. Update feeds or registries are refreshed automatically

**Never create releases manually.** Never use `gh release create` directly. If automation fails, fix the automation.

## Versioning

Use semantic versioning. Version is determined entirely from git tags — no VERSION file.

- **PATCH** (0.6.4 → 0.6.5) — bug fixes, small improvements
- **MINOR** (0.6.5 → 0.7.0) — new features, backwards compatible
- **MAJOR** (0.9.0 → 1.0.0) — breaking changes (commits marked `!` with a `BREAKING CHANGE:` footer), major milestones

## Release Types

See the detailed procedure for each release type:

- [stable.md](references/stable.md) — standard release: `release/vX.Y.Z` from develop, PR'd into main, tagged on main
- [beta.md](references/beta.md) — pre-release for testing: a `vX.Y.Z-beta.N` tag pushed on develop, no release branch
- [hotfix.md](references/hotfix.md) — critical patch: `hotfix/vX.Y.Z` cut from the release tag, PR'd into `main`, tagged on `main`

## Monitoring

```bash
gh run list --workflow=release.yml --limit 1
gh run watch <run-id>
gh release view v{VERSION}
```
