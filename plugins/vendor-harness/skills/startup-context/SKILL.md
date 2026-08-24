---
name: startup-context
description: Validate and diagnose startup context files — CLAUDE.md, AGENTS.md, copilot-instructions.md, rules — that inject instructions at session start across all four vendors.
---

Use this skill when working with files that inject instructions at startup — validating format, diagnosing why instructions aren't being read, or understanding load order and precedence per vendor.

**What startup context is:** Files that are automatically loaded into the model's context before any user prompt. Each vendor uses different file names and locations. All serve the same purpose: priming the model with project-specific or harness-level instructions.

**Vendor mapping:**

| Vendor | Primary file | Rules format | Legacy |
|--------|-------------|--------------|--------|
| Claude Code | CLAUDE.md | .claude/rules/*.md | — |
| Cursor | .cursor/rules/*.mdc | .cursor/rules/*.mdc | .cursorrules (root) |
| Codex | AGENTS.md | NOT SUPPORTED in plugins | — |
| Copilot CLI | AGENTS.md, CLAUDE.md, .github/copilot-instructions.md | .github/instructions/**/*.instructions.md (`applyTo` globs) | — |

**Load order (Claude Code):** User CLAUDE.md (~/.claude/CLAUDE.md) → Project CLAUDE.md → Plugin CLAUDE.md (via @-import). Rules in .claude/rules/ are loaded after CLAUDE.md.

**The @AGENTS.md workaround (Claude Code):** Claude Code does not natively read AGENTS.md. When ynh exports for Claude, it writes a CLAUDE.md containing only `@AGENTS.md` — using Claude's @-import syntax to pull in the cross-vendor instructions file without duplicating content.

**Copilot CLI needs no bridge:** it reads AGENTS.md, CLAUDE.md (and .claude/CLAUDE.md), GEMINI.md, and .github/copilot-instructions.md natively. It combines every applicable file rather than picking a winner, deduplicating identical content — so an existing `@AGENTS.md` bridge file is harmless but redundant. There is no defined precedence between these files: if two disagree, both reach the model.

**Diagnostic checklist:**
1. Is the file in the right location for the vendor?
2. Claude Code: does the plugin CLAUDE.md use @-import correctly?
3. Cursor: is the rules file .mdc (not .md)? Does it have required frontmatter (description, globs, alwaysApply)?
4. Codex: rules are not supported in plugin format — use AGENTS.md only
5. Copilot: is the path-scoped file `*.instructions.md` with an `applyTo` glob (not Cursor's
   `.mdc`/`globs`)? Do any @-imports use absolute or `~/` paths, or escape the repo? Those are
   silently not loaded. Run `/instructions` to see exactly what resolved.
6. Check file encoding and line endings — bare CR can cause silent failures
