---
"@eyelock-assistants/wheelhouse": patch
---

`open-pr.sh` opens the pull request from the current branch's upstream when its name differs from the local branch (a seat that pushed another seat's branch from its own worktree), takes an explicit `--head`, and defaults `--title` to the bead's title. `--base` still defaults to the repository's default branch; a gitflow repository passes `--base develop`.
