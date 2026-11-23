---
"@eyelock-assistants/dev-skills": patch
"@eyelock-assistants/triage-skills": patch
---

CI now lints every `.mjs` file with Biome, runs shellcheck at `warning` across the repository, and runs media-management's tests. The two shipped files that tripped the stricter gates changed without changing behaviour: `doc-candidates.sh` drops two `case` patterns an earlier one already covered, and `triage-questions.mjs` and its test are reformatted.
