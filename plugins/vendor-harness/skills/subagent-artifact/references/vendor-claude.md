# Claude Code — Subagent Reference

Docs: https://code.claude.com/docs/en/sub-agents

## Full Frontmatter Support

name: agent-name           # required
description: What it does  # required; used for routing
model: sonnet              # optional; override model
tools: Read, Bash, Grep    # optional; space-delimited
disallowedTools: Write     # optional; space-delimited
skills:                    # optional; array
  - skill-name
maxTurns: 10               # optional
effort: normal             # optional
memory: true               # optional
background: false          # optional
isolation: worktree        # optional

## Delegation

Native subagent system via Agent tool.
Delegates receive: AGENTS.md instructions, inlined rules, skill references.
agents/<name>.md in plugin root; loaded via --plugin-dir.

## Invocation

Orchestrating agent uses Agent tool with subagent_type matching the agent name.
Users can invoke directly via /agent-name if user-invocable.
