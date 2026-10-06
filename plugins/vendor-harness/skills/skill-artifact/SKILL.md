---
name: skill-artifact
description: Validate, diagnose, and understand Agent Skills (SKILL.md) across Claude Code, Cursor, Codex, and Copilot CLI — spec compliance, vendor loading behavior, and known quirks.
---

Use this skill when working with SKILL.md files — validating format, diagnosing why a skill isn't loading or appearing in the catalog, or understanding vendor-specific behavior differences.

**Validate the skill the user asked about** — read its SKILL.md and directory and apply the
checklist below. Do not audit this skill or other installed skills unless asked.

**Spec validation checklist:**
- Frontmatter must parse as YAML. Quote any value containing `: ` or ` #`. In Claude Code a
  parse failure is silent: `/name` still works, but the model never sees the description
  (see claude reference)
- `name`: required, lowercase a-z 0-9 hyphens only, must match directory name
- `description`: required, 1–1024 chars, used for catalog discovery — keep under 130 chars for large skill collections
- No other frontmatter fields are required by the agentskills.io spec
- `compatibility`, `license`, `metadata` fields exist in spec but trigger a loading bug in Claude Code — see claude reference

**Directory layout (agentskills.io):**
```
skill-name/
├── SKILL.md          # required
├── references/       # optional: loaded on demand
├── scripts/          # optional: must be chmod +x
└── assets/           # optional: templates, data
```

**Progressive disclosure (all vendors):**
- Catalog: name + description only (~50–100 tokens) — always loaded
- Instructions: full SKILL.md body — loaded when agent decides it's relevant or user invokes
- Resources: scripts/, references/, assets/ — loaded on demand when instructions reference them

**Invocation syntax by vendor:**
- Claude Code: `/plugin-name:skill-name`
- Codex: `$skill-name` (`@plugin-name skill-name` for a plugin's skills)
- Cursor: `/plugin-name:skill-name`
- Copilot CLI: `/skill-name`

**Skill directories by vendor:**
- Claude Code: plugin `skills/`, project `.claude/skills/`, user `~/.claude/skills/`
- Cursor: plugin `skills/`, project `.cursor/skills/` + `.agents/skills/` + `.claude/skills/` +
  `.codex/skills/`, and the same four under `~/`
- Codex: plugin `skills/`, repo `.agents/skills/` (cwd up to the repo root), user `~/.agents/skills/`.
  Codex reads no `.claude/`, `.cursor/` or `.github/` skill path
- Copilot CLI: plugin `skills/`, project `.github/skills/` + `.claude/skills/` + `.agents/skills/`,
  user `~/.copilot/skills/` + `~/.agents/skills/`

Cursor and Copilot both read Claude's project skill path, so a `.claude/skills/` skill is not
Claude-only: it loads in all three, but not in Codex. Only `.agents/skills/` reaches Cursor,
Copilot and Codex, and Claude Code does not read it: one copy for all four means a real
directory in one place and a symlink in the other.

Copilot resolves skills by `name`, first-found-wins, project skills before plugin skills, so a
project skill silently shadows a plugin skill of the same `name` — check that before anything
else when a plugin skill "isn't loading".

**Keeping a skill user-only (never model-invoked), per vendor:**
- Claude Code, Cursor: `disable-model-invocation: true` in the frontmatter
- Codex: ignores that field; add `agents/openai.yaml` beside SKILL.md with
  `policy: {allow_implicit_invocation: false}`
- Copilot CLI: no documented equivalent (VS Code's Copilot honors `disable-model-invocation`;
  the CLI docs do not list it). Do not rely on it: guard side effects in the body (confirm
  first), or leave the skill out of the Copilot build

**Limiting a skill to some files:** Claude Code and Cursor take `paths` in the frontmatter, glob
patterns (a comma-separated string or a YAML list, e.g. `paths: "**/*.tf"`) that keep the skill
inactive until matching files are in play; Cursor also accepts the legacy `globs`. Codex and
Copilot CLI skills have no such field (Copilot's `applyTo` belongs to `.instructions.md`
files, not skills): there, scope it in the description.

`argument-hint`, `user-invocable`, `model`, `context` and `agent` are Claude Code only. Say per
vendor what a field does, not that it "may" work.

For vendor-specific loading quirks (metadata demotion bug, context budget limits, extension fields), see the references/ directory.
