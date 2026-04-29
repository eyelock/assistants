---
name: skill-artifact
description: Validate, diagnose, and understand Agent Skills (SKILL.md) across Claude Code, Cursor, and Codex — spec compliance, vendor-specific loading behavior, and known quirks.
---

Use this skill when working with SKILL.md files — validating format, diagnosing why a skill isn't loading or appearing in the catalog, or understanding vendor-specific behavior differences.

**Before validating any skill, validate this one first:**
Check that `skill-artifact/SKILL.md` itself has no `metadata`, `compatibility`, or `license` fields (the Claude Code demotion bug applies to any skill, including this one), and that its description is under 130 chars. If this skill is broken, its validation output cannot be trusted.

**Spec validation checklist:**
- `name`: required, lowercase a-z 0-9 hyphens only, must match directory name
- `description`: required, 1–1024 chars, used for catalog discovery — keep under 130 chars for large skill collections
- No other frontmatter fields are required by the agentskills.io spec
- `compatibility`, `license`, `metadata` fields exist in spec but trigger a loading bug in Claude Code — see vendor-claude reference

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

For vendor-specific loading quirks (metadata demotion bug, context budget limits, extension fields), see the references/ directory.
