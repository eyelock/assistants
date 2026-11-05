---
"@eyelock-assistants/wheelhouse": minor
---

The human at the desk is per session, and no human but the default is written down. With no name given, the desk shows the default human's inbox; `inbox.sh show --name <Name>` ("it's me, <name>") adds that person's for the session: the beads assigned to their lowercase name and the ynm notes in `human/<command>`, with no roster entry. `inbox.sh register` and all email matching (`--email`, `WHEELHOUSE_HUMAN_EMAIL`, git's `user.email`) are gone, and nothing in the inbox writes to the repository. `assign` and `note` accept any human's command. The desk's wake no longer says "You haven't said who you are"; it says the human can name themselves. The roster's `humans` holds only the default human, and the doctor accepts an assignee that is a seat, the default human, or a human with a `human/<command>` namespace.
