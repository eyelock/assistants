---
"@eyelock-assistants/apple-calendar": minor
"@eyelock-assistants/platform-skills": minor
"@eyelock-assistants/triage-skills": patch
---

Add an `apple-calendar` platform skill and harness. It reads Apple Calendar on a Mac through `che-ical-mcp` (iCloud, Google and Exchange calendars) for unanswered invites, replies pending on invites you organized, clashes, and `catch-up` and `find`. `my-commitments` is not answered there. The server has no read-only mode, so a `before_tool` hook blocks every tool of the server except six calendar read tools; a test pins the hook's pattern against all 29 tools. macOS Calendar access is read and write, so the hook is the only barrier. "Since" is unknown, because the server returns no creation date.
