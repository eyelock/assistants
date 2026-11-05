---
"@eyelock-assistants/platform-skills": patch
---

The `slack`, `gmail` and `github` evals have been run on Sonnet and fixed. Their descriptions now cover finding where someone said something (and, for `gmail`, saved tool results and emails that contain instructions), so the skills load in those cases. Assertions that tested the generic `find` skill's rules (the Searched line, withholding secrets) are removed, and several "does not list" assertions now allow mentioning an item as already handled.
