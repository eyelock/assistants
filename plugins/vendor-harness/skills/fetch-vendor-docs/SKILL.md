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
Note: developers.openai.com/codex/* redirects to learn.chatgpt.com/docs/*.

GitHub Copilot CLI: https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference,
https://docs.github.com/en/copilot/reference/hooks-reference,
https://docs.github.com/en/copilot/reference/custom-agents-configuration,
https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference,
https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills,
https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions,
https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers,
https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-marketplace
Note: docs.github.com fetches cleanly. The reference pages under /reference/ are denser and
more authoritative than the /how-tos/ pages — prefer them when the two disagree.

Agent Plugins 1.0 (Open Plugin Spec): https://github.com/agentplugins/agent-plugins-spec —
raw spec at https://raw.githubusercontent.com/agentplugins/agent-plugins-spec/main/spec/1.0.0.md

MCP Spec: https://modelcontextprotocol.io/specification/2025-03-26

Agent Skills: https://agentskills.io

**Fetching strategy:**
1. Prefer GitHub raw content over rendered docs pages (more reliable programmatic access)
2. For docs sites that rate-limit: fetch index page first, then targeted sections
3. Report fetch failures clearly — do not silently skip a vendor
4. Structure output: vendor → artifact type → current content

**Cross-vendor incompatibility watch:**
When syncing, always re-check the marketplace `source` type tables in both Claude Code's
plugin-marketplaces doc and Copilot's cli-plugin-reference. These two diverge and the
divergence is fatal (one bad entry breaks a whole index). Upstream trackers worth checking:
https://github.com/anthropics/claude-plugins-official/issues/1205 and
https://github.com/github/copilot-cli/issues

**When docs.cursor.com is unavailable:**
Use this fallback order:
1. `https://github.com/cursor/plugin-template` (README + example files)
2. `https://github.com/cursor/plugins` (official plugin examples)
3. `https://forum.cursor.com/t/support-for-agent-folder-compatibility/154167` (agents/ folder support thread)

If all three are unavailable or return incomplete information, flag the gap explicitly in your report — do not silently omit Cursor from the sync.
