---
"@eyelock-assistants/wheelhouse": patch
---

The add-seat skill's report says in so many words that a trial seat is made official only by review and merge of its pull request (or is dropped), and says so when there is no remote and so no pull request yet. A seat committed with no remote to push to has its own worktree removed, and the seating seat picks a worktree path that does not exist yet and fixes a failed `git worktree add` before running anything else. Eval 13 (trial-branch) scored 3 to 4 of 5 on develop; it now passes 5 of 5 over three runs.
