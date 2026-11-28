---
"@eyelock-assistants/wheelhouse": patch
---

`wake.sh` no longer reads a failed or timed-out memory recall as an empty identity. The JSON gains `memoryRead` (false when the seat's own recall failed, as `workRead` is for bd), `firstWake` is then false, and the block says "Memory couldn't be read" instead of telling an established seat to use the birth skill. The `birth` skill says to stop, writing nothing, when memory can't be read, and a `memory-unreadable` eval checks it. A `wake-memory-broken` test covers a failed recall, a recall that gives up, and a real first wake (assistants #296).
