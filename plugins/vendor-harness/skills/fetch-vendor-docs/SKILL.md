---
name: fetch-vendor-docs
description: Fetch current documentation from LLM vendor sources — given a vendor or artifact type, retrieves up-to-date content from canonical URLs for comparison against stored references.
---

Use this skill when you need current vendor documentation — during a vendor sync, when diagnosing a vendor-specific behavior, or when verifying whether a known gap has been resolved.

**Canonical URLs by vendor:**

Claude Code: https://code.claude.com/docs/en/plugins, https://code.claude.com/docs/en/hooks-guide, https://code.claude.com/docs/en/mcp, https://code.claude.com/docs/en/sub-agents, https://code.claude.com/docs/en/settings

Cursor: https://github.com/cursor/plugin-template (README), https://docs.cursor.com/advanced/mcp, https://docs.cursor.com/advanced/rules
Note: docs.cursor.com aggressively rate-limits. Try GitHub sources first. Manual browsing may be needed.

Codex: https://developers.openai.com/codex/plugins, https://developers.openai.com/codex/plugins/build, https://developers.openai.com/codex/hooks, https://github.com/openai/codex (README)

MCP Spec: https://modelcontextprotocol.io/specification/2025-03-26

Agent Skills: https://agentskills.io

**Fetching strategy:**
1. Prefer GitHub raw content over rendered docs pages (more reliable programmatic access)
2. For docs sites that rate-limit: fetch index page first, then targeted sections
3. Report fetch failures clearly — do not silently skip a vendor
4. Structure output: vendor → artifact type → current content

**When docs.cursor.com is unavailable:**
Use this fallback order:
1. `https://github.com/cursor/plugin-template` (README + example files)
2. `https://github.com/cursor/plugins` (official plugin examples)
3. `https://forum.cursor.com/t/support-for-agent-folder-compatibility/154167` (agents/ folder support thread)

If all three are unavailable or return incomplete information, flag the gap explicitly in your report — do not silently omit Cursor from the sync.
