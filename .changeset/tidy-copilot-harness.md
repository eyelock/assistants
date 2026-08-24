---
"@eyelock-assistants/vendor-harness": minor
---

Add GitHub Copilot CLI as a fourth vendor in the vendor-harness plugin.

New `copilot.md` references for `vendor-adapters`, `skill-artifact`, `subagent-artifact`,
`mcp-artifact`, `hooks-artifact`, and `startup-context`, covering the plugin/marketplace
manifest resolution order, `agents/*.agent.md` custom agents, the `version: 1` two-level hook
format and its 14 events, MCP transports, and the `AGENTS.md`/`CLAUDE.md`/`copilot-instructions.md`
startup-context stack.

Documents the Claude Code ↔ Copilot CLI marketplace incompatibility: Copilot rejects the
`git-subdir`, `archive`, and `command` source types and fails the *entire* index rather than
skipping the offending entry, so one such row makes every plugin in a marketplace
uninstallable from Copilot. The two-index workaround is now implemented repo-wide: a
Copilot-safe `.github/plugin/marketplace.json` sits alongside the Claude index, version-synced
and drift-gated by `scripts/sync-manifests.mjs`.

Cross-cutting skills (`plugin-audit`, `fetch-vendor-docs`, `flag-vendor-gaps`,
`locate-artifact-source`, `submit-feedback`) and the `harness-advisor` / `vendor-sync` agents
now cover Copilot, and the known-gaps table tracks the new Copilot entries.

Behaviour is verified against Copilot CLI v1.0.80 rather than documentation alone, and the
reference records where the two disagree: `copilot plugin marketplace add` accepts a local
absolute path (useful for validating an index before pushing), `--plugin-dir` exists and is
undocumented on the web, `copilot plugins list` does not exist, and both `agents/*.md` and
`agents/*.agent.md` register.
