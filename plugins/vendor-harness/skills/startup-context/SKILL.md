---
name: startup-context
description: Validate and diagnose startup context files — CLAUDE.md, AGENTS.md, rules, and .cursorrules — that inject instructions into the model context at session start across Claude Code, Cursor, and Codex.
---

Use this skill when working with files that inject instructions at startup — validating format, diagnosing why instructions aren't being read, or understanding load order and precedence per vendor.

**What startup context is:** Files that are automatically loaded into the model's context before any user prompt. Each vendor uses different file names and locations. All serve the same purpose: priming the model with project-specific or harness-level instructions.

**Vendor mapping:**

| Vendor | Primary file | Rules format | Legacy |
|--------|-------------|--------------|--------|
| Claude Code | CLAUDE.md | .claude/rules/*.md | — |
| Cursor | .cursor/rules/*.mdc | .cursor/rules/*.mdc | .cursorrules (root) |
| Codex | AGENTS.md | NOT SUPPORTED in plugins | — |

**Load order (Claude Code):** User CLAUDE.md (~/.claude/CLAUDE.md) → Project CLAUDE.md → Plugin CLAUDE.md (via @-import). Rules in .claude/rules/ are loaded after CLAUDE.md.

**The @AGENTS.md workaround (Claude Code):** Claude Code does not natively read AGENTS.md. When ynh exports for Claude, it writes a CLAUDE.md containing only `@AGENTS.md` — using Claude's @-import syntax to pull in the cross-vendor instructions file without duplicating content.

**Diagnostic checklist:**
1. Is the file in the right location for the vendor?
2. Claude Code: does the plugin CLAUDE.md use @-import correctly?
3. Cursor: is the rules file .mdc (not .md)? Does it have required frontmatter (description, globs, alwaysApply)?
4. Codex: rules are not supported in plugin format — use AGENTS.md only
5. Check file encoding and line endings — bare CR can cause silent failures
