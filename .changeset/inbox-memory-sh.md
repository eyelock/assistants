---
"@eyelock-assistants/wheelhouse": minor
---

`inbox.sh note` and `inbox.sh show` read and write a human's notes through `memory.sh` (kind `note`, `--human <command>`), so they follow `wheelhouse.json` to ynm or Beads. `show` keeps its `notes` shape (`memoryId`, `content`) and adds `by` and `at`; its `relay` line names the backend's own retire command (`ynm forget ...` or `bd forget ...`). A failing memory is still an error and an inbox that is not `empty`, never an empty inbox.
