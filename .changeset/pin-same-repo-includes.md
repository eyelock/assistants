---
"@eyelock-assistants/wheelhouse": minor
"@eyelock-assistants/apple-calendar": patch
"@eyelock-assistants/david": patch
"@eyelock-assistants/github": patch
"@eyelock-assistants/gmail": patch
"@eyelock-assistants/google-calendar": patch
"@eyelock-assistants/google-drive": patch
"@eyelock-assistants/imessage": patch
"@eyelock-assistants/planner": patch
"@eyelock-assistants/researcher": patch
"@eyelock-assistants/slack": patch
"@eyelock-assistants/termq-dev": patch
"@eyelock-assistants/tester": patch
"@eyelock-assistants/ynh-dev": patch
---

Same-repository includes name a release tag, not `develop`. The add-seat and create-wheelhouse templates write `"ref": "@eyelock-assistants/wheelhouse@<version>"` (copied from the desk's own include), the add-seat eval checks it, the refresh skill says how a pin is moved ("Moving a pin"), and every `ynh/*` persona pins each include to its package's latest release tag, checked by `scripts/harness-picks.test.mjs`.
