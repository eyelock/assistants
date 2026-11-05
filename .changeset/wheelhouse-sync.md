---
"@eyelock-assistants/wheelhouse": minor
---

A Wheelhouse shares through its own repository: code, memory and the work graph. Every seat's wake syncs first (`ynm sync` with a git remote, `bd sync` with a Dolt remote), so it starts current, and names a sync that failed. create-wheelhouse wires the work graph to the repository's origin with `dolt.auto-push` on, asks before the first push, and says how to join from another machine. The doctor's new "work graph shared" check warns when there is a git remote but the work graph isn't shared through it.
