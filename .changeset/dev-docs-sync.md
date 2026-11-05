---
"@eyelock-assistants/dev-skills": minor
---

A `docs-sync` skill: given a branch, pull request or diff, it lists every doc the change should touch (user docs, reference tables, tutorials, help text, skills, `AGENTS.md`, behaviour comments and the pull request description), checks each against the code, including prose about a defect since fixed, and reports what is missing, stale or wrong before editing anything. Its read-only helper, `scripts/doc-candidates.sh`, collects the flags, environment variables, exported Go and TypeScript names, Cobra commands and make targets a diff touched, and finds the docs and help text that mention them, for Go layouts (`cmd/`, `internal/`) as well as TypeScript. It never reads `.env` files.
