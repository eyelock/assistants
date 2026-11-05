# Claude Code — Skill Artifact Reference

Docs: https://code.claude.com/docs/en/skills
      https://code.claude.com/docs/en/plugins
      https://code.claude.com/docs/en/plugins-reference

## Frontmatter That Does Not Parse

If the YAML frontmatter is malformed, Claude Code still loads the skill, but with empty
metadata: `/skill-name` works when typed, yet the model has no `description` to match, so it
never picks the skill up by itself. No error is shown in a normal session; `--debug` shows
the parse error, and `claude plugin validate <dir>` lists the files that fail.

The usual culprit is an unquoted `description` containing `: ` (colon then space), `#`
after a space, or a leading `[`, `{`, `*`, `&`, `!`, `|`, `>`, `'`, `"` or `%`. YAML reads
`description: Deploy with Helm: staging or production` as a nested mapping and fails. Quote
the value, or use a `>-` block scalar.

"Typing /name works, the model never uses it" → parse the frontmatter before anything else.

## Description Length

`description` plus `when_to_use` are truncated at 1,536 characters in the skill listing; put
the key use case first.

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
paths: "**/*.tf"                 # globs; skill stays inactive until matching files are in play (Cursor too)
when_to_use: "..."               # appended to description in the listing

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
