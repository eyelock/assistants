# Cursor — Subagent Reference

Docs: https://forum.cursor.com/t/support-for-agent-folder-compatibility/154167

## Supported Fields

name: agent-name
description: What it does

Richer frontmatter fields (model, tools, skills, maxTurns, etc.) are Claude-specific.
Cursor reads agents/<name>.md but ignores unknown frontmatter fields.

## Delegation Support

Status: NEEDS RESEARCH
Forum thread indicates .agents/ folder compatibility is under discussion.
Do not rely on Cursor subagent delegation until confirmed.

## Known Gaps

Cursor delegation/subagent invocation support is unconfirmed as of 2026-04-07.
