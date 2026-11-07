---
"@eyelock-assistants/wheelhouse": minor
---

The constitution, the seat charter and the starter worker now say a seat never changes a shared checkout: it works in its own git worktree in its scratchpad, branched from `origin/<default branch>`, names the worktree and its files with its own command (subagent seats share the desk's scratchpad), and never uses `git stash` (the stash list is shared by all worktrees). A branch already checked out elsewhere is pushed from a new local branch with `HEAD:<remote branch>`.
