# Claude Code — Skill Artifact Reference

Docs: https://code.claude.com/docs/en/plugins
      https://code.claude.com/docs/en/plugins-reference

## Known Bugs

### Metadata Demotion Bug
Skills with `compatibility`, `license`, or `metadata` frontmatter fields are demoted
in Claude Code. They receive minimal token allocation (~10 tokens) and are excluded
from agent context. The skill appears to load but is effectively invisible to the model.

Workaround: do not use these optional spec fields in Claude Code plugins. The ynd
create skill command already avoids them.

## Claude Code Extensions (not in agentskills.io spec)

disable-model-invocation: true   # user /invoke only; hidden from agent catalog
user-invocable: false            # hidden from / menu
model: sonnet                    # override model
context: fork                    # runs as isolated subagent
agent: general-purpose           # subagent type
argument-hint: "[text]"          # autocomplete hint

## Installation Paths

Plugin skills: loaded via --plugin-dir at launch
Project skills: .claude/skills/<name>/SKILL.md
User skills: ~/.claude/skills/<name>/SKILL.md

--plugin-dir auto-activates skills but NOT hooks or MCP (those require /plugin enable)

## Invocation

/plugin-name:skill-name   (namespaced)
/skill-name               (if unambiguous)

## Context Budget

2% of context window reserved for skill catalog.
~53 skills on 200K context window, ~260 on 1M.
