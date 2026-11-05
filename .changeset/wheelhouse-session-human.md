---
"@eyelock-assistants/wheelhouse": minor
---

The human at the desk is per session, and no human but the default is written down. With no name given, the desk shows the default human's inbox; `inbox.sh show --name <Name>` ("it's me, <name>") adds that person's for the session: the beads assigned to their lowercase name and the ynm notes in `human/<command>`, with no roster entry. Nothing in the inbox writes to the repository or stores a person, an email or a username. `assign` and `note` accept any human's command. The desk's wake says the human can name themselves. The roster's `humans` holds only the default human, and the doctor accepts an assignee that is a seat, the default human, a human command with a `human/<command>` namespace in ynm, or any human command on a bead labelled `inbox` (which `inbox.sh assign` puts on every bead it makes).
