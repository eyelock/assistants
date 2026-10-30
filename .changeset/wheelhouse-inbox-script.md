---
"@eyelock-assistants/wheelhouse": minor
---

The humans' inbox script, `work-graph/scripts/inbox.sh`, copied into every Wheelhouse as `scripts/inbox.sh`. `assign` makes a bead for a human (the default human unless `--to` names one), created as the seat that asked, with `--url` kept as its external reference and `--blocks` holding up the bead it waits for; a merge or review without a URL is refused. `note` leaves an FYI in ynm, namespace `human/<command>`, tagged `inbox`. `register` adds a person who names themselves at the desk, with their git email. `show` prints, as JSON, the ready beads and notes for the human at the desk (matched by git email, or `WHEELHOUSE_HUMAN_EMAIL`) and for the default human, each bead with who asked, its short form and URL, and how many beads it unblocks. Every name comes from the roster.
