---
name: branching
description: Gitflow branching model — develop/main strategy, branch naming, PR rules, and post-merge cleanup.
---

# Branching

## ABSOLUTE RULE — NEVER COMMIT DIRECTLY TO MAIN OR DEVELOP

Every change goes through a branch and PR — no exceptions, no matter how small or urgent.

- **Feature/fix work:** branch from `develop`, PR back into `develop`
- **Release promotion:** PR from `develop` → `main` (open at release time)
- **Hotfix:** branch from a release tag, fix on hotfix branch, CI passes, tag fires release — `main` never receives the commit directly; fix reaches `develop` via a forward-port PR after shipping

If the user has not yet created a branch, create one before touching any files:

```bash
git checkout -b <type>-<description>
```

Only the user can authorise a direct push to `main` or `develop`, and only for a specific stated technical reason. Never decide this unilaterally.

---

## Branch Naming

Use hyphens (not slashes) — keeps directories flat and scannable:

```
feat-<description>
fix-<description>
refactor-<description>
docs-<description>
ci-<description>
test-<description>
```

Examples: `feat-user-auth`, `fix-login-redirect`, `ci-add-lint-check`

## Commit Count Before Pushing

Ask: **what is the minimum number of commits that meaningfully separates this work?**

Feature/fix branch PRs use squash-merge (`gh pr merge --squash`), so branch commits are ephemeral — they become one commit on `develop` regardless. Their only job is to help a reviewer understand the PR. That means:

- Lean toward 1–3 commits per PR, one per logical concern
- WIP checkpoints, format commits, and implementation-journey fixes → squash them away
- The PR description carries the narrative; commits are just grouping for review

```bash
git log origin/develop..HEAD --oneline   # read it — if you'd be embarrassed showing it, squash
git rebase -i origin/develop             # fixup/reword until only meaningful separations remain
```

> Note: for the `develop → main` release promotion PR, these become `origin/main`.

## Before Creating a PR

Ensure the branch is up-to-date with the base branch (`develop` for feature branches):

```bash
git fetch origin develop
git log HEAD..origin/develop --oneline   # if output, merge first
git merge origin/develop
git push
```

## Merge Rules

**NEVER use `gh pr merge --admin`** — this bypasses CI and is strictly forbidden.

Only merge when:
- All CI checks pass
- All review comments addressed and conversations resolved
- Branch is up-to-date with base

```bash
gh pr checks            # verify all pass
gh pr view --comments   # verify no unresolved comments
gh pr merge --squash    # feature/fix branches → develop
```

**Exception — release promotion PR (`develop` → `main`):** always use `--merge` (true merge), never `--squash`. Squash loses ancestry and makes `git log v{VERSION}..develop` show the entire history as if nothing was released.

```bash
gh pr merge --merge     # develop → main only
```

## Post-Merge Cleanup

```bash
# Verify merged into develop (for feature branches)
git branch -r --merged origin/develop | grep <branch-name>

# For release promotion PRs, verify merged into main:
git branch -r --merged origin/main | grep <branch-name>

# Clean up local branch
git branch -d <branch-name>
git push origin --delete <branch-name>
```
