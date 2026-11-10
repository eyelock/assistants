---
"@eyelock-assistants/wheelhouse": minor
---

`add-seat` seats one seat at a time, as a trial. The seating seat writes the seat on a branch `seat/<command>` in its own worktree, pushes it, opens a draft pull request and removes its worktree; the human checks the branch out in the shared checkout, runs `ynh install ./harnesses/<command>` and trials it (install, birth and work are real; the roster entry and the desk's `delegates_to` wait for the end of the trial). It becomes official on review, merge and reinstall from the same path, or is dropped: the pull request closed, `ynh uninstall`, its beads handed to the seat the roster's new `winds_down` key names (the desk when unset), and its name added to `excluded`. The batch "set up the team" walk is gone: the starter team's roles are offered one at a time. The reviewer template keeps a trial seat's pull request in draft until the trial ends. Every install command in the skill reads `./harnesses/<command>`.
