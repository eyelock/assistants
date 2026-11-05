---
"@eyelock-assistants/wheelhouse": minor
---

Memory syncs itself, as the work graph does. create-wheelhouse turns on ynm's `sync.auto` (ynm 0.5.0 or later) in `.ynm/config.json`, so ynm syncs memory in the background after a turn, at most every 5 minutes. The doctor's new "memory syncs itself" check warns when it's off, reading the `sync` block the way ynm layers its config files, and errors when ynm is older than 0.5.0, which refuses that block.
