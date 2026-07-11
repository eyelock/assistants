# Cursor — Startup Context Reference

Docs: https://docs.cursor.com/advanced/rules

## Files

Current rules: .cursor/rules/<name>.mdc  (frontmatter + markdown)
Legacy: .cursorrules  (project root, deprecated but still read)
AGENTS.md: read by Cursor (cross-vendor compatibility)

## Rules Format (.mdc)

---
description: What this rule does
globs: "*.ts,*.tsx"      # file pattern; empty = always apply
alwaysApply: true        # boolean
---

Rule content in markdown below frontmatter.

## Known ynh Discrepancy

ynh writes rules as .md files — Cursor expects .mdc with frontmatter.
Whether Cursor reads plain .md rules without frontmatter is unconfirmed.
HIGH priority gap: ynh should write .mdc with globs/alwaysApply frontmatter.

## AGENTS.md

Cursor reads AGENTS.md natively — no workaround needed.
Use AGENTS.md as the cross-vendor instructions file; Cursor reads it directly.

## .cursorrules

Deprecated. Still read for backwards compatibility.
Prefer .cursor/rules/*.mdc for new projects.
