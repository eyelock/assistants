---
"@eyelock-assistants/wheelhouse": minor
---

A bare session in a Wheelhouse repository is told it is not a seat. `create-wheelhouse` copies `scripts/bare-guard.sh` into the Wheelhouse and, with `scripts/add-bare-guard-hook.sh` (an append-only, idempotent merge that keeps every other key and hook), writes a project-level session-start hook that runs it, for each vendor the desk and seats run on: Claude Code (`.claude/settings.json`), Codex (`.codex/hooks.json`) and Cursor (`.cursor/hooks.json`). A plain session is told it is not the desk or any seat, so it does not claim beads or write seat memory. A session started through ynh is told nothing: the guard reads `YNH_LABELS`, which ynh exports to the vendor it starts, for the `wheelhouse:<name>` label every seat's harness carries (needs ynh 0.17.0 or later). Copilot CLI and OpenCode have no project-level session-start hook the guard can use, and the skill says so. The doctor warns about a vendor with no guard.

Per-vendor behaviour is unverified: no live Claude Code, Codex or Cursor session has been run.
