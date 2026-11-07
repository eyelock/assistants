---
"@eyelock-assistants/wheelhouse": minor
---

`wake.sh` reads a seat's identity, handoff notes, Kudos and close notes, and the Wheelhouse's shared facts (capped at ten), through `memory.sh`, so a Wheelhouse whose `wheelhouse.json` says `"memory": "beads"` wakes from Beads memories. With Beads, memory and work sync with one `bd sync` (skipped without a Dolt remote), reported for both, at wake and at `--end` (which keeps its single shared budget: 25 seconds by default, at most 28). The retire command in the block matches the backend. `wake.sh` needs `memory.sh` beside it; `create-wheelhouse` copies both.
