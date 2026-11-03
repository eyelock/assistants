# Pinned skills

The skills `ynh-dev` includes from outside this repository, each pinned to a full 40-character
commit SHA in `.agents/harness/plugin.json`. To move a pin, vet the new SHA again and replace the
entry here in the same change.

## golang-pro

| | |
|---|---|
| Include | `https://github.com/Jeffallan/claude-skills`, pick `skills/golang-pro` |
| Pinned SHA | `078a25cc5bfd8011459be7b91d004e900c1d02d3` (the head of `main` on 2026-11-03: "feat(site): skill page titles lead with the skill's name (#312)") |
| Publisher | Jeffallan (the maintainer of the repository), Synergetic Solutions; the repository is public and MIT licensed |
| License | MIT, in `LICENSE` at the repository root, and `license: MIT` in the skill's frontmatter |
| Vetted | 2026-11-03, bead ynw-t54 |
| Last change to the skill | `130a59c`, 2026-10-25: "fix(skills): correct Go, WebSocket and Kubernetes examples (#268)" |

### Files read, in full, at that SHA

All six files of the skill, 49,639 bytes. None is a symlink or an executable; there are no scripts.

- `skills/golang-pro/SKILL.md`
- `skills/golang-pro/references/concurrency.md`
- `skills/golang-pro/references/generics.md`
- `skills/golang-pro/references/interfaces.md`
- `skills/golang-pro/references/project-structure.md`
- `skills/golang-pro/references/testing.md`

Also read: `LICENSE`.

What they hold: Go guidance and code examples (concurrency, generics, interfaces, project layout,
testing). Nothing asks the agent to run a command, fetch anything, change settings or reveal
anything. Commands appear only inside examples for the reader's own Go project (`go mod`,
`go test`, `golangci-lint`, a Makefile, a Dockerfile, and `go install ...@latest` in a code
comment). The skill's own steps tell the agent to run `go vet`, `golangci-lint` and the race
detector, which suits ynh.

### SkillSpector at that SHA

Run on 2026-11-03 with `ghcr.io/eyelock/skillspector:1 gate .` over the skill at the pinned SHA
(`git archive` of `skills/golang-pro`): 2 active findings, both severity HIGH, rule AE1:

| Finding | Where | Reading |
|---|---|---|
| AE1: referenced artifact was not completely inspected (`references/concurrency.md` (partial)) | `SKILL.md:36` | The scanner read only part of a long reference file. All of it was read by hand (see above) and holds only Go examples. Accepted. |
| AE1: referenced artifact was not completely inspected (`references/generics.md` (partial)) | `SKILL.md:38` | Same. Accepted. |

Neither finding is about the skill's content. The include is outside this repository, so CI's
SkillSpector job never scans it and no rule is added to `.skillspector-baseline.yaml`.
