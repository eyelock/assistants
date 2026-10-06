---
name: flag-vendor-gaps
description: Maintain the vendor gap table — add new gaps, update existing entries, and mark gaps as resolved when vendor support improves.
---

Use this skill when you discover a gap in vendor support, or when a known gap has been resolved.

**Gap table location:** one table for all vendors, `vendor-adapters/references/known-gaps.md`.
Read it before adding anything.

**Gap entry format** (rows as they appear there):

```
| Priority | Description | Vendor | Status |
|----------|-------------|--------|--------|
| HIGH | ynh has no Copilot CLI adapter — no plugin.json, marketplace, hooks or MCP config generated | Copilot CLI | OPEN (2026-08-24; Copilot falls back to Claude's files) |
| HIGH | Copilot rejects a `git-subdir` marketplace source — the whole index fails | Copilot CLI, Claude Code | MITIGATED (2026-08-24; Copilot-safe .github/plugin/marketplace.json published alongside) |
| MED | Copilot hook config needs top-level `"version": 1` and two-level nesting | Copilot CLI | OPEN (2026-08-24) |
| MED | Cursor plugin hooks format mismatch (flat legacy vs three-level) | Cursor | RESOLVED (eyelock/ynh#197 / #203, 2026-08-19 — ynh writes both paths) |
| LOW | SessionStart canonical event not mapped | All | RESOLVED (eyelock/ynh#204, 2026-08-19 — mapped as `on_session_start`) |
```

**Status values:** OPEN; RESOLVED (fixed — say what and when); MITIGATED (worked around on
our side, upstream cause still open); WITHDRAWN (the gap was wrong — say what disproved it).

**Priority guidance** — judge by what happens to the user, not by how hard the fix is:
- HIGH: incorrect behavior. The artifact does the wrong thing or silently does nothing on a
  vendor it targets: a hook or guard that never runs, a skill or agent that loads without
  its instructions, an install or index that fails, generated output in the wrong format or
  place, a confidently wrong answer.
- MED: degraded behavior or compatibility. It still works, but with less capability or only
  after a known adaptation: a format that must be converted when porting, a field one vendor
  ignores with a usable fallback, docs that disagree with the shipped binary.
- LOW: cosmetic or display-only, a missing optimization, or something that still needs research.

**When adding a gap:**
1. Check if it already exists in the table — update rather than duplicate
2. Assign priority based on impact
3. Note which vendor(s) are affected — Claude Code, Cursor, Codex, Copilot CLI (comma-separated if several), or All
4. Write the description as what goes wrong, then what should happen instead, in so many
   words ("...; it should ..."). A workaround is not the correct behavior: put it in the
   Status note

**When resolving a gap:**
1. Update status to RESOLVED (or MITIGATED if only worked around), and keep the row
2. Add resolution note: what changed and when
3. Update the relevant reference file to reflect the corrected behavior
