---
name: branching
description: Gitflow branching model — develop/main strategy, branch naming, PR rules, and post-merge cleanup.
---

# Branching

## ABSOLUTE RULE — NEVER COMMIT DIRECTLY TO MAIN OR DEVELOP

Every change goes through a branch and PR — no exceptions, no matter how small or urgent.

- **Feature/fix work:** branch from `develop`, PR back into `develop`
- **Stable release:** cut `release/vX.Y.Z` from `develop`, PR it into `main`, merge with `--merge`, and the tag fires the release — `develop` never opens a PR into `main` directly
- **Hotfix:** `hotfix/vX.Y.Z` cut from the release tag, PR'd into `main` with `--merge` once CI passes; the merge commit on `main` is tagged, which fires the release; then forward-ported to `develop` by PR

If the user has not yet created a branch, create one before touching any files:

```bash
git checkout -b <type>/<description>
```

Only the user can authorize a direct push to `main` or `develop`, and only for a specific stated technical reason. Never decide this unilaterally.

---

## Branch Naming

Use a slash after the type prefix:

```
feat/<description>
fix/<description>
refactor/<description>
docs/<description>
ci/<description>
test/<description>
chore/<description>
release/vX.Y.Z      # cut from develop, PR into main
hotfix/vX.Y.Z       # cut from the release tag being patched
```

Examples: `feat/user-auth`, `fix/login-redirect`, `ci/add-lint-check`, `release/v1.4.0`, `hotfix/v1.3.1`, `fix/forward-port-v1.3.1`

Worktrees nest to match: `feat/user-auth` lives at `.worktrees/feat/user-auth/`.

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

> Note: for a `release/vX.Y.Z` or `hotfix/vX.Y.Z` PR into `main`, these become `origin/main`.

## Before Creating a PR

Ensure the branch is up-to-date with the base branch (`develop` for feature/fix branches, `main` for `release/*` and `hotfix/*`):

```bash
BASE=develop   # main for release/* and hotfix/*
git fetch origin "$BASE"
git log HEAD..origin/"$BASE" --oneline   # if output, merge first
git merge origin/"$BASE"
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

**Exception — PRs into `main` (`release/vX.Y.Z` or `hotfix/vX.Y.Z` → `main`):** always use `--merge` (true merge), never `--squash`. Squash loses ancestry and makes `git log v{VERSION}..develop` show the entire history as if nothing was released. `develop` itself never opens a PR into `main` — a stable release always goes through a `release/vX.Y.Z` branch (see the `release` skill).

```bash
gh pr merge --merge     # release/* or hotfix/* → main only
```

## Post-Merge Cleanup

Check the PR itself is merged. After a squash merge, git cannot tell: the branch's own commits
never enter `develop`'s history, so `git branch --merged` does not list it and `git branch -d`
refuses to delete it.

```bash
gh pr view <branch-name> --json state,mergedAt   # state must be MERGED

# Squash-merged feature/fix branches: -D, now that GitHub confirms the merge
git branch -D <branch-name>
git push origin --delete <branch-name>

# release/* and hotfix/* (true merges into main): git can confirm, and -d is enough
git branch -r --merged origin/main | grep <branch-name>
git branch -d <branch-name>
git push origin --delete <branch-name>
```
