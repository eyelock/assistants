---
"@eyelock-assistants/wheelhouse": patch
---

The desk now passes on that the human can name themselves for the session. The wake block's note was a passive aside the desk could drop; it now tells the desk to say so after the inbox, every time, and the wake skill says the same. `inbox.sh show` carries the same instruction in its `relay` text when no name is given, so a desk that reads the inbox directly passes it on too. The wake skill's eval cases cover the invitation, including on an empty inbox.
