---
name: push
description: Push committed work, open a PR targeting the correct base branch, monitor CI, and merge when ready.
---

# Push

Push committed work, open a PR targeting the correct base branch, monitor CI, and merge when ready.

1. **Determine the base branch** from the current branch name:
   - `develop` or `hotfix/*` → base is `main`
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

7. When all CI checks pass, report the result and **ask before merging**:
   ```bash
   gh pr merge --squash
   ```

8. After merge: delete the remote branch and local branch.
   Feature branches verify against `origin/develop`; `develop` and `hotfix/*` verify against `origin/main`.

   ```bash
   git branch -r --merged origin/<base> | grep <branch-name>
   git branch -d <branch-name>
   git push origin --delete <branch-name>
   ```
