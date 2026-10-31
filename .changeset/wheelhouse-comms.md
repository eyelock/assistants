---
"@eyelock-assistants/wheelhouse": minor
---

A `comms` skill for how the seats talk to the humans. Its first rule is that a seat never names a human in anything posted or written (pull requests, reviews, comments, beads, notes, docs, commits): it writes the next action impersonally, and calls the human "you" in chat. Decisions are asked through the vendor's question tool (Claude Code's `AskUserQuestion`), up to 4 per call, each with a line of context and 2 to 4 options, the recommended one first and labelled "(Recommended)", or as a numbered list with lettered options where there is no question tool. Every bead id gets a synopsis, web resources their linked short form and local paths their full path, and messages lead with the outcome. The constitution template gains the rule, the desk's charter, add-seat's charter template and the designer and reviewer templates point to the skill, and the tutorial's constitution follows.
