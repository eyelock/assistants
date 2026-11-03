# Pinned skills

The skills `ynh-dev` includes from outside this repository, each pinned to a full 40-character
commit SHA in `.agents/harness/plugin.json`. A third-party skill needs a nameable publisher, every
file read, and a SkillSpector scan with 0 active findings and no baseline suppressions. To move a
pin, vet the new SHA again and replace the entry here in the same change.

## affaan-m/everything-claude-code: golang-patterns and golang-testing

| | |
|---|---|
| Include | `https://github.com/affaan-m/everything-claude-code`, pick `skills/golang-patterns` and `skills/golang-testing` |
| Pinned SHA | `b38be6a7f6350964d59328b52f0624e1d1d552d1` (the head of `main` on 2026-11-03: "Merge pull request #3809 from affaan-m/maint/pr-continuation-20261029", committed 2026-10-29) |
| Publisher | Affaan Mustafa (GitHub `affaan-m`); a public repository |
| License | MIT, in `LICENSE` at the repository root ("Copyright (c) 2026 Affaan Mustafa") |
| Vetted | 2026-11-03, bead ynw-cbm7 (follow-up to ynw-t54) |

### Files read, in full, at that SHA

Each skill is a single file, read with `cat -v`. Neither has a `references/`, scripts, symlinks or
other files.

- `skills/golang-patterns/SKILL.md` (14,497 bytes)
- `skills/golang-testing/SKILL.md` (16,744 bytes)

Also read: `LICENSE`.

What they hold: Go guidance and code examples (idioms, error handling, concurrency, interfaces,
layout, performance; table-driven tests, benchmarks, fuzzing, coverage). The only non-ASCII bytes
are box-drawing characters in a directory tree, arrows and one dash. Nothing asks the agent to run
a command of its own, fetch anything, change settings or reveal anything; the commands shown are
`go`, `golangci-lint` and a GitHub Actions snippet, as examples for the reader's own project.

### SkillSpector at that SHA

Run on 2026-11-03 with `ghcr.io/eyelock/skillspector:1 gate .` over `skills/golang-patterns` and
`skills/golang-testing` as exported by `git archive` at the pinned SHA:
`scanned 2 skill(s), 0 active finding(s), 0 suppressed`.

## Candidates rejected

Scanned on 2026-11-03 with the same command, at the SHA named.

| Candidate | SHA | Result |
|---|---|---|
| `Jeffallan/claude-skills`, `skills/golang-pro` (the previous include; MIT) | `078a25cc5bfd8011459be7b91d004e900c1d02d3` | 2 active HIGH findings, rule AE1 "referenced artifact was not completely inspected", on `references/concurrency.md` and `references/generics.md`. The cause is not known (the files are not long). Not accepted. |
| `wshobson/agents`, `plugins/systems-programming/skills/go-concurrency-patterns` (MIT) | `7e2fb559cf4b824b27f1fec49fe88f7511066d26` | 1 active HIGH finding, AE1, on `references/details.md`. |
| `samber/cc-skills-golang`, 46 `golang-*` skills (MIT) | `bb1d43d98a3f8ab639a0042f90d0ec524e39a477` | 112 active findings across 31 skills, including `golang-code-style`, `golang-concurrency`, `golang-error-handling` and `golang-testing`. Fifteen skills scan clean, such as `golang-context` and `golang-structs-interfaces`, but none covers concurrency, error handling or testing. |
