---
name: skill-artifact
description: Validate, diagnose, and understand Agent Skills (SKILL.md) across Claude Code, Cursor, Codex, and Copilot CLI — spec compliance, vendor loading behavior, and known quirks.
---

Use this skill when working with SKILL.md files — validating format, diagnosing why a skill isn't loading or appearing in the catalog, or understanding vendor-specific behavior differences.

**Before validating any skill, validate this one first:**
Check that `skill-artifact/SKILL.md` itself has no `metadata`, `compatibility`, or `license` fields (the Claude Code demotion bug applies to any skill, including this one), and that its description is under 130 chars. If this skill is broken, its validation output cannot be trusted.

**Spec validation checklist:**
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
- Codex: `@plugin-name skill-name`
- Cursor: `/plugin-name:skill-name`
- Copilot CLI: `/skill-name`

**Skill directories by vendor:**
- Claude Code: plugin `skills/`, project `.claude/skills/`, user `~/.claude/skills/`
- Cursor: plugin `skills/`, project `.cursor/skills/`, plus `.agents/skills/`
- Codex: plugin `skills/`
- Copilot CLI: plugin `skills/`, project `.github/skills/` + `.claude/skills/` + `.agents/skills/`,
  user `~/.copilot/skills/` + `~/.agents/skills/`

Copilot reads Claude's project skill path, so a `.claude/skills/` skill loads in both. Copilot
resolves skills first-found-wins, so a project skill silently shadows a plugin skill of the
same `name` — check that before anything else when a plugin skill "isn't loading".

For vendor-specific loading quirks (metadata demotion bug, context budget limits, extension fields), see the references/ directory.
