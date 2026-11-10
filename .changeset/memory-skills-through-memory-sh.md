---
"@eyelock-assistants/wheelhouse": minor
---

The memory skills give one instruction per action, through `scripts/memory.sh`, instead of naming ynm or `bd remember`. `birth` writes the identity and the birth record with `memory.sh remember` (it replaces and pins the identity itself), `handoff` writes, recalls and retires handoff notes with `remember`, `recall` and `forget`, `kudos` records and reads Kudos, the `wake` fallback recalls identity, handoff, Kudos and close notes, and `work-graph` writes close notes and shared facts the same way. Whether memory lives in ynm or Beads is `wheelhouse.json`'s business, not the skills'. New evals run `handoff` and `kudos` with the memory in Beads.
