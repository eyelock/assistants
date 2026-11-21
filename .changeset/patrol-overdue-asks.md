---
"@eyelock-assistants/wheelhouse": minor
---

`patrol.sh` reports an overdue ask once. It reads the open asks through `ask.sh show --all` (where the Wheelhouse has a work graph and an `ask.sh`) and prints an `ask-overdue` change for each ask whose age passed the threshold since the last patrol (default 24h; `$WHEELHOUSE_ASK_OVERDUE_AFTER` or `--ask-overdue-after` sets it), never again while it stays open. An `ask:report` is never overdue. An `ask.sh` that fails is an `error` change (source `asks`) and the last asks are kept. The patrol skill tells the seat to report the changes to the desk as an `ask:report`.
