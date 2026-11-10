---
"@eyelock-assistants/wheelhouse": patch
---

`memory.sh recall` on ynm gives a memory's text exactly as it was written: ynm appends the string values of a memory's `--data` (`<kind> <by> [<bead>]`) to its content as a last line, and `recall` now strips that line, so close notes, handoffs and kudos no longer end with it and inbox notes parse again. A test runs the real ynm, not a stub.
