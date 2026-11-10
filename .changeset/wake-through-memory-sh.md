---
"@eyelock-assistants/wheelhouse": minor
---

`wake.sh` reads a seat's identity, handoff notes, Kudos and close notes, and the Wheelhouse's shared facts (capped at ten), through `memory.sh`, so it follows `wheelhouse.json`'s `memory` key and a Wheelhouse that says `"memory": "beads"` wakes from Beads memories. It recalls the seat's memory once and splits it by kind, so a wake costs one `memory.sh` read for the seat and one for the facts. With Beads, memory and work sync with one `bd sync` (skipped without a Dolt remote) that gives one result for both, at wake and at `--end` (which keeps its single shared budget: 25 seconds by default, at most 28). The retire command in the block matches the backend, and the facts show on either. The JSON gains `backend` and `facts`. `wake.sh` needs `memory.sh` beside it; `create-wheelhouse` copies both.
