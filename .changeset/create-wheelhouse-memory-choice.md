---
"@eyelock-assistants/wheelhouse": minor
---

`create-wheelhouse` asks where Agent Tasks (Beads, the only option) and Agent Memory (ynm, the default, or Beads) live, and records the answer in `wheelhouse.json` at the Wheelhouse root. It copies `memory.sh` beside `wake.sh` and `inbox.sh` for either choice, writes the constitution's second rule to match, and for Beads memory skips `ynm init`, `ynm client install ynh`, the ynm sync config and push hook, and the ynm prerequisite. `add-seat` installs the ynm client into a seat only for ynm memory, and the README says the same. New evals cover both choices, and the Beads one expects the doctor to pass with no hand edits.
