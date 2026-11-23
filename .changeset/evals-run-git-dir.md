---
"@eyelock-assistants/wheelhouse": patch
---

The skill evals keep each run's git directory outside its launch directory, so a seat can `git worktree add` under Claude Code's sandbox, which keeps the launch directory's `.git/worktrees` read-only. add-seat's evals scored 77.5% before and 98% after, and the `trial-over-crew` assertion asks only for what a fixture with no remote can say (assistants #273).
