---
"@eyelock-assistants/wheelhouse": minor
---

The desk wakes to the humans' inbox. Its wake block opens with "For the humans": a section for the human at the desk (matched by git email) and one for the default human, each with the ready beads assigned to them (a pull request or page as its short form in a Markdown link, the bead's id, who asked and how many beads it unblocks) and the notes left for them, and an instruction to relay it first and retire each note once relayed. Someone the desk doesn't know is invited to say "it's me, <name>". Other seats' wakes are unchanged; the JSON gains an `inbox` field, null for them. When bd or ynm fails, the block says the inbox couldn't be read in full and why, and which beads or notes couldn't be read, never "Nothing waiting for the humans."
