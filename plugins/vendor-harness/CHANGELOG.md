# @eyelock-assistants/vendor-harness

## 0.3.0

### Minor Changes

- [#36](https://github.com/eyelock/assistants/pull/36) [`516c3c7`](https://github.com/eyelock/assistants/commit/516c3c778eee2dd78841c3089b7e50ea270072ba) Thanks [@eyelock](https://github.com/eyelock)! - Add GitHub Copilot CLI as a fourth vendor in the vendor-harness plugin.

  New `copilot.md` references for `vendor-adapters`, `skill-artifact`, `subagent-artifact`,
  `mcp-artifact`, `hooks-artifact`, and `startup-context`, covering the plugin/marketplace
  manifest resolution order, `agents/*.agent.md` custom agents, the `version: 1` two-level hook
  format and its 14 events, MCP transports, and the `AGENTS.md`/`CLAUDE.md`/`copilot-instructions.md`
  startup-context stack.

  Documents the Claude Code ↔ Copilot CLI marketplace incompatibility: Copilot rejects the
  `git-subdir`, `archive`, and `command` source types and fails the _entire_ index rather than
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

### Patch Changes

- [#40](https://github.com/eyelock/assistants/pull/40) [`42f7d68`](https://github.com/eyelock/assistants/commit/42f7d68b760e23f953552dd343bb617a2891cb6e) Thanks [@eyelock](https://github.com/eyelock)! - Fix agent `tools:` frontmatter stripping capability on Copilot, and correct the marketplace
  source-type table with tested results.

  `tools:` is restrictive and the two vendors do not share a tool namespace. A Claude-authored
  list (`Read, Write, WebFetch, Bash`) leaves an agent without those capabilities on Copilot.
  This broke `vendor-sync`, which could not fetch vendor documentation at all — the only thing
  it exists to do. All four agents now list both vocabularies.

  GitHub's documented custom-agent tool aliases turn out not to work in `tools:` either: `web`
  is published as the alias for `WebFetch`/`WebSearch`, and neither grants fetch — only the raw
  `web_fetch` does. Recorded as an upstream docs bug.

  Corrects the marketplace source-type table. It claimed Copilot supports `npm`, taken from
  issue prose rather than testing; `npm` is rejected, as are `archive` and `command`, exactly
  like `git-subdir`. All seven types were probed against Copilot CLI v1.0.80 — Copilot accepts
  exactly three: relative path, `github` (with optional `path`), and `url`.

  Also makes `provenance-detective` actually run its committer check rather than reporting
  `unknown` without trying.

- [#37](https://github.com/eyelock/assistants/pull/37) [`f137e6c`](https://github.com/eyelock/assistants/commit/f137e6c801e57ed6c06ff7459618c8de90d9a565) Thanks [@eyelock](https://github.com/eyelock)! - Fix vendor-harness agents losing their skills on every vendor except Claude Code.

  The `skills:` frontmatter field is Claude Code-only. Cursor, Codex, and Copilot CLI parse the
  agent and ignore the key — silently, with no warning — so the agent runs without any of the
  knowledge it was built around and answers from the base model instead. Observed on Copilot CLI
  v1.0.80: `harness-advisor` claimed Copilot rejects `{"source":"github","repo":...}` marketplace
  sources, the exact opposite of the truth, while the same question asked without the agent
  wrapper invoked `vendor-adapters` and answered correctly.

  All four agents now name their skills as an explicit instruction in the prompt body, explain
  that the frontmatter list is Claude-only, and keep the `skills:` key for the vendor that
  honours it. `harness-advisor` is also told to propose changes rather than edit and commit them.

  Documents the trap in `subagent-artifact` as a general portability rule — Claude-only
  frontmatter fields (`skills`, `disallowedTools`, `maxTurns`, `effort`, `memory`, `background`,
  `isolation`, `permissionMode`) are inert elsewhere, and model aliases like `model: sonnet` do
  not resolve on Copilot (it warns and falls back to `auto`).

## 0.2.1

### Patch Changes

- [#28](https://github.com/eyelock/assistants/pull/28) [`e68936d`](https://github.com/eyelock/assistants/commit/e68936d1e4da98cb4552dcc1990cc632d589a2f6) Thanks [@eyelock](https://github.com/eyelock)! - Sync vendor reference docs (Claude Code, Codex, Cursor) with current vendor documentation and with fixes landed in eyelock/ynh. Updates hook event lists, MCP transport/format details, subagent frontmatter fields, plugin manifest fields, and the known-gaps table; corrects several stale "needs fix" entries that were already resolved in ynh.

## 0.2.0

### Minor Changes

- [#10](https://github.com/eyelock/assistants/pull/10) [`5db2e73`](https://github.com/eyelock/assistants/commit/5db2e731740f941265eb3bd4a07914ede7a6f858) Thanks [@eyelock](https://github.com/eyelock)! - Add vendor-harness plugin: lifecycle management for LLM vendor harness artifacts — validate, diagnose, trace provenance, compose and submit feedback, and keep vendor references current across Claude Code, Cursor, and Codex.
