---
"@eyelock-assistants/imessage": minor
"@eyelock-assistants/platform-skills": patch
---

The `imessage` harness now reads message text by default (`--privacy full`), because triage cannot tell a question from a thank-you or a reply without it. Profile `redacted` hides the text, and `counts` is unchanged. The profile named `full` is gone, and `commitments`, `catch-up` and `find` no longer need to select it. The skill's notes say that in `redacted` mode every chat you spoke last in looks alike, so those are candidates, not confirmed waits.
