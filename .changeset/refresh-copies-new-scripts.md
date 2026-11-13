---
"@eyelock-assistants/wheelhouse": patch
---

`refresh.sh --update` copies in `wake.sh`, `inbox.sh` and `memory.sh` when a Wheelhouse lacks one, so a Wheelhouse built before `memory.sh` existed gets it and can wake (before, it left a script the Wheelhouse didn't carry alone, and the new `wake.sh` stopped with exit 3). Optional scripts (patrol, tracker, open-pr) are still left alone when not carried. The doctor now reports a missing `scripts/memory.sh` as an error.
