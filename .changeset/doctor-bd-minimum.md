---
"@eyelock-assistants/wheelhouse": minor
---

The `doctor` skill fails on a `bd` older than 1.3.0 (a new "beads version" check, with the minimum in `wheelhouse-lib.sh` as `WL_BD_MIN`), the release that added `bd update --if-assignee` and `--if-status`, which the claim and session-hold scripts rely on. The README states the minimum. The `memory.sh` grep fallback for `ynm remember --json` stays until ynm documents `memoryId` as a contract.
