# OpenAI Codex — Skill Artifact Reference

Docs: https://learn.chatgpt.com/docs/build-skills
      https://developers.openai.com/codex/plugins
      https://developers.openai.com/codex/plugins/build

## Skill Location

Plugin skills: skills/<name>/SKILL.md at plugin root.
Codex discovers the root `skills/` directory by default, so the manifest does not need a
`skills` field. `"skills": "./skills/"` in .codex-plugin/plugin.json is optional; it is what
`@plugin-creator` emits, and it is the way to point at a non-default directory.

ynh exports Codex skills to `skills/` at the plugin root (the old `.agents/skills/` path was
fixed in eyelock/ynh#186; see known-gaps in vendor-adapters).

Standalone skills, in this order:

1. Repository: `.agents/skills/` in the working directory and each parent up to the repo root
2. User: `$HOME/.agents/skills/`
3. Admin: `/etc/codex/skills/`
4. System: bundled with Codex

Codex does not read `.claude/skills/`, `.cursor/skills/` or `.github/skills/`. Two skills
with the same `name` are not merged or shadowed: both appear in the skill selector.

## Frontmatter

Codex supports: name, description (standard agentskills.io fields only)
Claude Code extensions, `disable-model-invocation` included, are ignored.

## Stopping Implicit Invocation

Codex's equivalent of `disable-model-invocation` lives beside SKILL.md, not in it:

```yaml
# <skill>/agents/openai.yaml
policy:
  allow_implicit_invocation: false
```

With it, Codex never picks the skill up from the prompt; `$skill-name` still runs it.

## Invocation

`$skill-name` in Codex CLI and the IDE extension, `/skills` for the selector
@plugin-name skill-name for a plugin's skills
