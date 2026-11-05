# @eyelock-assistants/dev-skills

## 0.2.0

### Minor Changes

- [#93](https://github.com/eyelock/assistants/pull/93) [`1086997`](https://github.com/eyelock/assistants/commit/1086997ce2ecb7e6233c39f44fd94f83db41f57b) Thanks [@eyelock](https://github.com/eyelock)! - A `docs-sync` skill: given a branch, pull request or diff, it lists every doc the change should touch (user docs, reference tables, tutorials, help text, skills, `AGENTS.md`, behaviour comments and the pull request description), checks each against the code, including prose about a defect since fixed, and reports what is missing, stale or wrong before editing anything. Its read-only helper, `scripts/doc-candidates.sh`, collects the flags, environment variables, exported Go and TypeScript names, Cobra commands and make targets a diff touched, and finds the docs and help text that mention them, for Go layouts (`cmd/`, `internal/`) as well as TypeScript. It never reads `.env` files.

### Patch Changes

- [#50](https://github.com/eyelock/assistants/pull/50) [`c3f171c`](https://github.com/eyelock/assistants/commit/c3f171cb7488dc42188d8d53dd9d9bad6ff9b33e) Thanks [@eyelock](https://github.com/eyelock)! - Add evals for every dev skill and fix what they exposed: dev-review gets a severity scale, finding format and verdict; dev-security an absent-controls checklist; dev-debug triggers on its symptoms; dev-project drops the mandatory empty pkg/; skill-creator pushes back on an oversized SKILL.md; gh-cli sections.
