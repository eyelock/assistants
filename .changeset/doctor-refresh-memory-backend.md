---
"@eyelock-assistants/wheelhouse": minor
---

The doctor and the refresh skill check memory by the backend `wheelhouse.json`'s `memory` key names, read through `memory.sh`. With ynm (the default) nothing changes. With Beads the doctor skips ynm's checks, so a Beads Wheelhouse with no ynm installed is clean, and instead checks that Beads memory is readable (`bd --readonly memories --json` parses) and shared (a Dolt remote; a warning without one). "Seats born" and "assignees known" go through `memory.sh` for Beads, and `refresh.sh` finds a seat's identity the same way. A `memory` key that is neither `ynm` nor `beads` is a doctor error. Beads' own agent setup (`bd prime`) is still refused.
