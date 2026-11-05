---
"@eyelock-assistants/triage-skills": patch
---

`find`, `my-commitments` and `add-triage-question` now fire for the requests they were written for: `find` was never used in its own evals because its description did not say it applies to a single small lookup, so it also now says what it adds (where, when, a link, what was searched, and no repeated secrets). `find` rows start with a Where column that names the channel, thread, mail subject or pull request, not only the platform.
