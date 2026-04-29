# Claude Code — Startup Context Reference

Docs: https://code.claude.com/docs/en/memory

## Files

Project: CLAUDE.md (project root)
User: ~/.claude/CLAUDE.md
Plugin: CLAUDE.md (inside plugin directory — loaded via --plugin-dir)
Rules: .claude/rules/<name>.md (modular rules, plain markdown)

## Load Order

1. User CLAUDE.md
2. Project CLAUDE.md
3. Plugin CLAUDE.md (loaded when plugin is active)
4. .claude/rules/*.md (after CLAUDE.md)

## @-Import Syntax

CLAUDE.md supports @-imports to pull in other files:
  @AGENTS.md   (pulls AGENTS.md content inline)
  @path/to/file.md

## The AGENTS.md Workaround

Claude Code does not natively read AGENTS.md.
ynh exports a plugin CLAUDE.md containing only: @AGENTS.md
This bridges Claude Code to the cross-vendor AGENTS.md without content duplication.
The plugin's CLAUDE.md lives inside the plugin directory; no conflict with project CLAUDE.md.

## Rules Format

Plain markdown. No frontmatter required.
Path: .claude/rules/<name>.md
Content appended to context; multiple rules files all loaded.

## Notes

Plugin settings.json only supports the "agent" key — not suitable for rules config.
--append-system-prompt flag can inject instructions without a file.
