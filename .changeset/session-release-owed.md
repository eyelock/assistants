---
"@eyelock-assistants/wheelhouse": patch
---

A seat the desk runs as a subagent no longer gets stuck behind its own earlier run. The `--end` session release retries when bd is busy, and when it still cannot reach bd it leaves a note in `TMPDIR` that the session's token owes the seat a release. The next start of that seat by the same session (subagents share the desk's session id, so its token) finds a hold with its own token and that note, takes the hold back (`session.state: held`, `resumed: true`, shown as "Hold taken back") instead of being refused, and clears the note. A hold with the same token and no note is still refused, as another subagent of the seat may be live.
