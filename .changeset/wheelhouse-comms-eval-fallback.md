---
"@eyelock-assistants/wheelhouse": patch
---

The comms one-question eval checks the plain-text fallback. It needed `AskUserQuestion`, which the eval session can't load, so it could not pass; the case now says the session has no question tool and checks the lettered-options fallback the skill gives.
