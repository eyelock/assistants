---
"@eyelock-assistants/wheelhouse": minor
---

Seats can no longer miss the comms rules. Every wake block now ends with a line sending the seat to the `comms` skill before it talks to the human, and `create-wheelhouse`'s constitution template gains a rule 12: every decision goes through the vendor's question tool, and every report ends with Status, Work in progress and Your action. The `comms` skill's description now triggers on any question, decision or report put to a human. Section 2 says a decision asked in prose is a breach where a question tool exists, and independent decisions now share one call (up to the tool's limit, 4 in Claude Code) while a dependent decision waits for the next. Section 4 gains the closing shape, Status, Work in progress and Your action, and names an action only once its preconditions hold. New evals cover several independent decisions, a dependent one, and an action that isn't ready; a wake test covers the closing line.
