---
"@eyelock-assistants/vendor-harness": patch
---

The vendor-adapters references name the Copilot and Cursor install scripts by URL instead of quoting `curl … | bash`, so an agent reading them is not handed a pipe-to-shell command.
