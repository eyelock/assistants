---
name: flag-vendor-gaps
description: Maintain the vendor gap table — add new gaps, update existing entries, and mark gaps as resolved when vendor support improves.
---

Use this skill when you discover a gap in vendor support, or when a known gap has been resolved.

**Gap entry format:**

```
| Priority | Description | Vendor | Status |
|----------|-------------|--------|--------|
| HIGH | Codex plugin manifest not generated | Codex | OPEN |
| HIGH | Codex skills export path wrong (.agents/skills/ should be skills/) | Codex | OPEN |
| MED | Cursor plugin hooks format mismatch (flat legacy vs three-level) | Cursor | OPEN |
| MED | Cursor .mdc rules format (ynh writes .md, Cursor wants .mdc) | Cursor | OPEN |
| LOW | SessionStart canonical event not mapped | All | OPEN |
```

**Priority guidance:**
- HIGH: causes incorrect behavior or broken output (wrong format, missing file)
- MED: causes degraded behavior or compatibility issues
- LOW: missing optimization, needs research, cosmetic

**When adding a gap:**
1. Check if it already exists in the table — update rather than duplicate
2. Assign priority based on impact
3. Note which vendor(s) are affected
4. Add a brief description of what the correct behavior should be

**When resolving a gap:**
1. Update status to RESOLVED
2. Add resolution note: what changed and when
3. Update the relevant reference file to reflect the corrected behavior

**Gap table location:** vendor-adapters skill, references/ directory for each vendor.
