---
"@eyelock-assistants/triage-skills": minor
"@eyelock-assistants/imessage": minor
---

The common triage list grows by three questions, `my-commitments` (what I promised and have not done), `catch-up` (where a conversation, thread or topic stands) and `find` (where something was said), and `add-triage-question` says when a new question belongs on the list and when it does not, keeps every platform harness in step with the list (`scripts/triage-questions.mjs check` and `sync`), and is checked by `pnpm test`. The iMessage harness is the first to answer all of them; the others are marked `todo` in the list and follow in their own changes. The iMessage `commitments` focus is renamed `my-commitments`.
