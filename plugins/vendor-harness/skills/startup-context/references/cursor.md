# Cursor — Startup Context Reference

Docs: https://cursor.com/docs/context/rules (docs.cursor.com/advanced/rules now redirects here)

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

FIXED (eyelock/ynh#196, eyelock/ynh#201, merged 2026-08-19): ynh's Cursor adapter
(`internal/vendor/cursor.go`, `Cursor.TransformArtifact`) now renames `.md` → `.mdc`
and injects `description`/`alwaysApply: true` frontmatter at copy time (both
`ynh run` staging and `ynh export`). No `globs` is emitted — ynh has no per-rule
glob metadata to source it from.
Background: a plain .md file in .cursor/rules is silently ignored — the rules
system requires .mdc with frontmatter.

## Rules Tiers

Project rules: .cursor/rules/*.mdc (per-repo)
User rules: Cursor settings (per-user, not checked into repo)
Team rules: dashboard-managed, Team/Enterprise plans only

## AGENTS.md

Cursor reads AGENTS.md natively — no workaround needed.
Use AGENTS.md as the cross-vendor instructions file; Cursor reads it directly.

## .cursorrules

Deprecated. Still read for backwards compatibility.
Prefer .cursor/rules/*.mdc for new projects.
