---
"@eyelock-assistants/wheelhouse": minor
---

`memory.sh` gains an `event` kind for what happened to a bead: shared, needs `--bead`, and left out of `recall --shared` (which gives facts) unless asked for with `--kind event`, so a bead outcome never tops a wake's "What the Wheelhouse knows". `work-graph`'s closing step writes the outcome as an event, not a shared fact.
