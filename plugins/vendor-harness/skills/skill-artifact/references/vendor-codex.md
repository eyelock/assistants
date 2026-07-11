# OpenAI Codex — Skill Artifact Reference

Docs: https://developers.openai.com/codex/plugins
      https://developers.openai.com/codex/plugins/build

## Skill Location

Plugin skills: skills/<name>/SKILL.md at plugin root
Plugin manifest must explicitly point to skills dir:
  "skills": "./skills/"  in .codex-plugin/plugin.json

## Known ynh Export Bug

ynh currently exports Codex skills to .agents/skills/ — should be skills/ at plugin root.
This is a known HIGH priority gap.

## Frontmatter

Codex supports: name, description (standard agentskills.io fields only)
Claude Code extensions are ignored.

## Invocation

@plugin-name skill-name
