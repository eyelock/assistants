---
name: push
description: Push committed work, open a PR targeting the correct base branch, monitor CI, and merge when ready.
---

# Push

Push committed work, open a PR targeting the correct base branch, monitor CI, and merge when ready.

1. **Determine the base branch** from the current branch name:
   - `release/*` or `hotfix/*` → base is `main`
   - Any other branch → base is `develop` (`develop` itself never opens a PR into `main`; a
     stable release goes through a `release/vX.Y.Z` branch — see the `release` skill)

2. **Review commit count** — run `git log origin/<base>..HEAD --oneline`. Since this project
   squash-merges, lean toward 1–3 commits per PR. WIP checkpoints, format commits, and
   implementation-journey fixes should be squashed away before pushing. See the `branching`
   skill for guidance.

3. **Ensure the branch is up-to-date** with the base:
   ```bash
   git fetch origin <base>
   git log HEAD..origin/<base> --oneline   # if output, merge before pushing
   git merge origin/<base>
   ```

4. **Push the branch** to origin.

5. **Create a PR** with an explicit base — use the `commits` skill for title and description format:
   ```bash
   gh pr create --base <base> --title "<title>" --body "<body>"
   ```

6. **Monitor CI** — report each check's status as it completes.

7. When all CI checks pass, report the result and **ask before merging**.

8. Merge and clean up — order is critical when working from a worktree:

   **Step A** — capture context and merge while CWD is still valid:
   ```bash
   MAIN_REPO=$(git worktree list --porcelain | head -1 | sed 's/^worktree //')
   WORKTREE_PATH=$(git rev-parse --show-toplevel)
   BRANCH=$(git branch --show-current)
   gh pr merge --squash   # feature/fix branches → develop
   # Exception: release/* and hotfix/* PRs into main must use --merge, not --squash
   ```

   A `release/*` or `hotfix/*` merge into `main` is not the end: tag the merge commit on
   `main` (never the branch) to fire the release, and forward-port a hotfix to `develop`
   through its own branch and a PR into `develop`, never a direct push. The `release` skill
   has the steps.

   **Step B** — run the cleanup script. The skill base directory is shown at the top of
   this file when loaded — use it to locate the script:
   ```bash
   bash "<skill-base>/scripts/post-merge-cleanup.sh" "$MAIN_REPO" "$WORKTREE_PATH" "$BRANCH"
   ```
