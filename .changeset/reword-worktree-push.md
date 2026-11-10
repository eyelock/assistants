---
"@eyelock-assistants/wheelhouse": patch
---

The worktree rule no longer tells a seat to push with a raw `HEAD:` refspec, which SkillSpector flags: a branch already checked out elsewhere is recreated tracking its remote branch and pushed with `git -c push.default=upstream push`.
