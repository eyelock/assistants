---
"@eyelock-assistants/platform-skills": minor
"@eyelock-assistants/slack": minor
"@eyelock-assistants/github": minor
"@eyelock-assistants/gmail": minor
"@eyelock-assistants/google-calendar": minor
"@eyelock-assistants/google-drive": minor
---

Add platform-skills, a package of vendor skills (how to work well in one tool through its MCP server): `slack`, `github`, `gmail`, `google-calendar` and `google-drive`. Each platform harness includes its own skill and keeps only what is specific to its server and credentials.

Breaking: the `calendar` and `drive` harnesses are renamed `google-calendar` and `google-drive`. Anyone who installed the old names must reinstall under the new ones.
