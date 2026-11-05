---
name: docs-sync
description: Check that the docs still match the code after a change - user docs, reference tables, tutorials, help text, skills, AGENTS.md, comments that describe behaviour and the pull request description - and report every doc that is missing, stale or wrong, including prose about a defect that has since been fixed. Report first; edit only when asked. Use before handing over or reviewing a branch or pull request, when asked whether the docs are up to date, for docs drift, or to bring docs and a PR description in line with the code.
allowed-tools: Bash Read Grep Glob
---

# Docs sync

A change is not done while the docs describing it are wrong. This skill finds every doc a change
should touch, checks each one against the code as it now is, and reports what is missing, stale
or wrong. It reports first. Change a doc only when you are asked to fix what you found, and then
only the docs in the report.

## 1. Pin down the change

The change is a branch, a pull request or a diff. By default, the current branch against where it
left the default branch, with uncommitted changes included. For a pull request, read its diff and
its description (`gh pr view <n> --json body,title,files`, `gh pr diff <n>`).

## 2. List the candidates

Run the helper from the repository root:

```bash
bash <this skill>/scripts/doc-candidates.sh [--base <ref>]
```

It reads the diff, collects the names the change touched (flags, environment variables, exported
Go and TypeScript names, Cobra commands, make targets), marks each `added`, `removed` or
`changed` and whether it is still in the code, and lists every tracked doc that mentions one,
with the lines and any caveat lines ("known issue", "workaround", "not yet supported"). It skips
`.env` files, history (`CHANGELOG.md`, `.changeset/`) and vendored or built folders, and changes
nothing.

The list is a start, not the answer: a doc can be wrong about a change without naming anything
the diff touched. Add, by reading:

| Kind | Where to look |
|---|---|
| User docs | `README.md`, `docs/`, any docs site source |
| Reference tables | flag, command, field, exit-code and environment-variable tables; JSON or schema field lists |
| Tutorials | step-by-step pages, and the output they say to expect |
| Help text | Go: `cmd/` and Cobra's `Use`, `Short`, `Long`, `Example` and flag usage strings; TypeScript: the CLI's `.description()`, `.option()` and usage strings |
| Skills and checklists | `SKILL.md` files and any checklist a person or agent follows |
| `AGENTS.md`, `CLAUDE.md` | rules and commands for agents, including build and test commands |
| Behaviour comments | doc comments on changed functions and types (Go's `// Name ...`, TSDoc), and comments that say what code does, in `internal/`, `pkg/`, `src/` or `lib/` |
| The PR description | what it says the change does, what was verified, and what it closes |

Look past the diff: a doc the change leaves untouched can be the one it made wrong.

## 3. Check each one against the code

Read the code as it now is, not the diff alone, and compare:

- **Names and shapes:** every flag, command, field, environment variable, default and exit code
  the doc names exists, and means what the doc says. A `removed` name still documented is stale.
  An `added` one nowhere documented is missing, if users meet it.
- **Behaviour:** what the doc says happens is what the code does, including errors and edge cases.
- **Examples:** commands still run as written, and expected output still matches.
- **Defects since fixed:** caveats, known issues, workarounds and "doesn't yet" lines about
  something the change fixed are now wrong. Search for them by symptom, not only by name.
- **The PR description:** it describes the branch's head, not an earlier version; it names what
  was and wasn't verified; every link and short id is right.

## 4. Report

One finding per doc that needs work, grouped by kind, each with:

- the doc and line (`docs/reference.md:12`), and its kind;
- **missing**, **stale** or **wrong**, and what it says now;
- the evidence in the code (`cmd/tool/sync.go:41`) that shows the truth;
- the fix in a sentence.

Then the docs you checked that are right, in one line, so the reader knows they were looked at.
End with the verdict: the docs are in sync, or how many need work. Don't edit anything until asked.

## Rules

- Never open `.env` files or anything holding secrets; a doc names an environment variable, it
  never needs its value.
- Report from the code, not from memory or the diff alone.
- Report every finding, however small: a wrong flag in a table is as wrong as a missing page.
