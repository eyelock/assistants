# OpenAI Codex — Startup Context Reference

## Files

Primary: AGENTS.md (project root) — read natively by Codex
Export: ynh writes AGENTS.md to staging dir for Codex

## Rules

Rules are NOT supported in Codex plugin format.
Encode all instructions in AGENTS.md.

## Plugin Startup Context

ynh writes AGENTS.md as codex.md in the staging directory for Codex.
(Implementation detail — the file is renamed to match Codex's expected name.)

## Notes

No @-import syntax in Codex.
No rules directory support.
AGENTS.md is the single source of startup instructions.
