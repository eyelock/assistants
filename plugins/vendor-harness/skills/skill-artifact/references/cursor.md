# Cursor — Skill Artifact Reference

Docs: https://cursor.com/docs/context/skills
      https://github.com/cursor/plugin-template
      https://github.com/cursor/plugins
      https://cursor.com/marketplace

## Skill Location

Plugin skills: skills/<name>/SKILL.md at plugin root

Project skills (all are read):
- `.cursor/skills/<name>/SKILL.md`
- `.agents/skills/<name>/SKILL.md`
- `.claude/skills/<name>/SKILL.md`   ← Claude Code project skills load in Cursor too
- `.codex/skills/<name>/SKILL.md`

User skills: the same four under `~/` (`~/.cursor/skills/`, `~/.agents/skills/`,
`~/.claude/skills/`, `~/.codex/skills/`).

## Frontmatter

Cursor supports: `name`, `description` (required), `paths` (legacy `globs`),
`disable-model-invocation`, `icon`, `color`, `metadata`.

- `disable-model-invocation: true` works as in Claude Code: the skill is added to context
  only when the user types `/skill-name`.
- `metadata` is fine here: the demotion bug is Claude Code's alone.
- Other Claude Code extensions (`argument-hint`, `user-invocable`, `model`, `context`,
  `agent`) are ignored.

## Invocation

/plugin-name:skill-name

## Known Gaps

Cursor reads .agents/skills/ but NOT .agents/rules/ or other .agents/ subdirs.
Metadata demotion bug not present in Cursor.
