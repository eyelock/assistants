---
"@eyelock-assistants/wheelhouse": patch
---

`inbox.sh assign --kind merge` now refuses a pull request that is still a draft, saying why, when `gh` can tell; without `gh` it warns and carries on. The work-graph skill says to ask a human to merge only once the pull request has left draft.
