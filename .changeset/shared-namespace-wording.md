---
"@eyelock-assistants/wheelhouse": patch
---

The birth, handoff and create-wheelhouse skills no longer call a seat's namespace a "private home": every seat's memory is written at ynm's distributed level, so the namespace is its own to write and shared with the team. A test fails if a skill or template calls it private again (assistants #302).
