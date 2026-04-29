# Cursor — Skill Artifact Reference

Docs: https://github.com/cursor/plugin-template
      https://github.com/cursor/plugins
      https://cursor.com/marketplace

## Skill Location

Plugin skills: skills/<name>/SKILL.md at plugin root
Project skills: .cursor/skills/<name>/SKILL.md
.agents/skills/: Cursor reads this path (partial support — skills only, not rules or other subdirs)

## Frontmatter

Cursor supports: name, description (standard agentskills.io fields only)
Vendor extensions (disable-model-invocation, model, context, etc.) are Claude-specific and ignored.

## Invocation

/plugin-name:skill-name

## Known Gaps

Cursor reads .agents/skills/ but NOT .agents/rules/ or other .agents/ subdirs.
Metadata demotion bug not present in Cursor.
