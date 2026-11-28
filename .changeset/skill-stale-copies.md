---
"@eyelock-assistants/wheelhouse": patch
---

The work-graph skill no longer calls `inbox.sh` a copy at the Wheelhouse root, and marks the patrol's unanswered-ask flag as planned until assistants #263 merges. The header of the doctor's `memory-checks.sh` says it uses the plugin's `memory.sh`, which is what the code does (assistants #300).
