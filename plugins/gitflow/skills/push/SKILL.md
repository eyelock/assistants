---
name: push
description: Push committed work, open a PR targeting the correct base branch, monitor CI, and merge when ready.
---

# Push

Push committed work, open a PR targeting the correct base branch, monitor CI, and merge when ready.

1. **Determine the base branch** from the current branch name:
   - `develop`, `hotfix/*`, or `release/*` → base is `main`
   - Any other branch → base is `develop`

2. **Review commit count** — run `git log origin/<base>..HEAD --oneline`. Since this project
   squash-merges, lean toward 1–3 commits per PR. WIP checkpoints, format commits, and
   implementation-journey fixes should be squashed away before pushing. See the `commits` skill
   for guidance.

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
   # Exception: release promotion PR (develop → main) must use --merge, not --squash
   ```

   **Step B** — run the cleanup script. The skill base directory is shown at the top of
   this file when loaded — use it to locate the script:
   ```bash
   bash "<skill-base>/scripts/post-merge-cleanup.sh" "$MAIN_REPO" "$WORKTREE_PATH" "$BRANCH"
   ```
