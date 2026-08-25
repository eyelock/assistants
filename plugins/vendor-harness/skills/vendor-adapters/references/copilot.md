# GitHub Copilot CLI — Vendor Reference

## Documentation URLs

- Product page: https://github.com/features/copilot/cli
- About CLI plugins: https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-cli-plugins
- Creating a plugin: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-creating
- Creating a marketplace: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-marketplace
- Plugin reference: https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference
- Command reference: https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference
- Programmatic reference: https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-programmatic-reference
- Config directory reference: https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference
- Hooks reference: https://docs.github.com/en/copilot/reference/hooks-reference
- Custom agents configuration: https://docs.github.com/en/copilot/reference/custom-agents-configuration
- Add agent skills: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills
- Add custom instructions: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions
- Add MCP servers: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers
- Issue tracker: https://github.com/github/copilot-cli
- Agent Plugins (Open Plugin Spec) 1.0: https://github.com/agentplugins/agent-plugins-spec

## Plugin Format

Manifest: `plugin.json`. Copilot CLI resolves it from the first of these that exists:

1. `.plugin/plugin.json`
2. `plugin.json` (plugin root — canonical for Agent Plugins 1.0)
3. `.github/plugin/plugin.json`
4. `.claude-plugin/plugin.json`  ← **a Claude Code plugin already resolves without changes**

Required: `name` only — kebab-case, letters/numbers/hyphens, max 64 chars. Dots (`acme.tools`)
are rejected **unless** the plugin opts into Open Plugin Spec semantics by setting `$schema`
to the canonical Agent Plugins v1.0.0 schema URL.

Optional metadata: `$schema`, `description` (max 1024), `version`, `author` (`{name, email?, url?}`),
`homepage`, `repository`, `license`, `keywords`, `category`, `tags`.

Component pointers in manifest (all optional):

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `agents` | string \| string[] | `agents/` | `*.agent.md` **or** plain `*.md` — both register |
| `skills` | string \| string[] | `skills/` | `SKILL.md` per subdirectory |
| `commands` | string \| string[] | — | file format not documented as of 2026-08-24 — prefer skills |
| `hooks` | string \| object | — | path to hooks config, or inline hooks object |
| `extensions` | string \| string[] \| object | — | `{paths, exclusive}` — `exclusive: true` suppresses built-in extensions |
| `mcpServers` | string \| object | — | path to `.mcp.json`, or inline server map |
| `lspServers` | string \| object | — | path to `lsp.json`, or inline server map |

## Plugin Directory Structure

```
plugin-root/
  plugin.json                   (manifest — see resolution order above)
  agents/<name>.agent.md        (custom agents — plain <name>.md also works)
  skills/<name>/SKILL.md        (agent skills)
  hooks.json                    (hook config — or hooks/hooks.json)
  .mcp.json                     (MCP servers — or .github/mcp.json)
  lsp.json                      (LSP servers — or .github/lsp.json)
```

## Marketplace Format

Index resolution order (first found wins):

1. `marketplace.json`
2. `.plugin/marketplace.json`
3. `.github/plugin/marketplace.json`  ← recommended when a Claude marketplace also exists
4. `.claude-plugin/marketplace.json`

```json
{
  "name": "my-marketplace",
  "owner": {"name": "Your Organization", "email": "plugins@example.com"},
  "metadata": {"description": "Curated plugins", "version": "1.0.0", "pluginRoot": "./plugins"},
  "plugins": [
    {
      "name": "frontend-design",
      "description": "...",
      "version": "2.1.0",
      "source": "./plugins/frontend-design"
    }
  ]
}
```

Top-level: `name` (required, kebab-case, max 64), `owner` (required, `{name, email?}`),
`plugins` (required), `metadata` (optional — `{description?, version?, pluginRoot?}`).

Plugin entry: `name` + `source` required. Optional: `description`, `version`, `author`,
`homepage`, `repository`, `license`, `keywords`, `category`, `tags`, `commands`, `agents`,
`skills`, `hooks`, `mcpServers`, `lspServers`, `strict`.

`strict` defaults to `true` — the entry must conform to the full schema. `strict: false`
relaxes validation, useful for legacy or direct installs.

## Marketplace Source Types — the Claude Code incompatibility

**This is the single biggest cross-vendor trap.** Copilot CLI and Claude Code share a
marketplace file format and Copilot will happily read `.claude-plugin/marketplace.json` —
but their `source` discriminated unions are **not** the same set.

All rows below are tested against Copilot CLI v1.0.80, not inferred from docs.

| `source` type | Claude Code | Copilot CLI |
|---------------|-------------|-------------|
| relative path string (`"./plugins/x"`) | ✓ | ✓ tested |
| `{"source": "github", "repo": …}` | ✓ (no `path`) | ✓ tested (**`path` supported**, tested) |
| `{"source": "url", "url": …}` | ✓ (no `path`) | ✓ tested |
| `{"source": "git-subdir", "url": …, "path": …}` | ✓ (only Claude type with `path`) | ✗ **rejected** (tested) |
| `{"source": "npm", "package": …}` | ✓ | ✗ **rejected** (tested) |
| `{"source": "archive", "url": …, "sha256": …}` | ✓ | ✗ **rejected** (tested) |
| `{"source": "command", "command": …}` | ✓ | ✗ **rejected** (tested) |

Copilot's accepted set is exactly three: relative path, `github`, `url`. Every other Claude
source type fails the whole index. Note `npm` in particular — it is widely repeated as
Copilot-supported (including in anthropics/claude-plugins-official#1205), and it is not:
`{"source":"npm","package":"@scope/x"}` yields `plugins.N.source: Invalid input` like the rest.

Both vendors accept `ref` (branch/tag) and `sha` (full 40-char commit SHA) on git-backed
object sources; `sha` overrides `ref` and pins against force-pushes and moved tags.

**Failure mode:** an unrecognised `source` type does **not** skip that one entry. Copilot
validates the whole index against a discriminated union and aborts the entire marketplace:

```
Failed to add marketplace: Invalid marketplace.json: plugins.2.source: Invalid input,
  plugins.5.source: Invalid input, plugins.12.source: Invalid input, ...
```

One `git-subdir` entry therefore makes every plugin in the marketplace uninstallable from
Copilot CLI. Same fail-whole-file behaviour for a non-kebab-case plugin name:

```
plugins.120.name: Plugin name must be kebab-case (letters, numbers, and hyphens)
```

Real-world instance: `anthropics/claude-plugins-official` — 14 `git-subdir` plugins plus
`wordpress.com` broke the whole index for Copilot CLI users
(https://github.com/anthropics/claude-plugins-official/issues/1205, and
https://github.com/anthropics/claude-plugins-official/issues/585 for the older-Claude-client
half of the same problem).

**Portability rules:**

1. Prefer relative-path sources for plugins living in the marketplace repo — universally supported.
2. Never emit `git-subdir`, `npm`, `archive`, or `command` in a file that Copilot may read.
   For `git-subdir` the capability is available to
   Copilot as `{"source": "github", "repo": "owner/repo", "path": "tools/plugin"}` — it is the
   `git-subdir` *discriminator* Copilot rejects, not the subdirectory concept. Claude Code does
   not accept `path` on its `github`/`url` types, so a single file cannot express a git
   subdirectory for both vendors.
3. When both are needed, ship two indexes: keep `git-subdir` entries in
   `.claude-plugin/marketplace.json` and publish a Copilot-safe `.github/plugin/marketplace.json`.
   Copilot finds `.github/plugin/` first, Claude only looks at `.claude-plugin/`.
4. Keep every plugin name kebab-case unless you opt into the Open Plugin Spec via `$schema`.

## Install Specifications

| Format | Example |
|--------|---------|
| Marketplace | `plugin@marketplace` |
| GitHub repo root | `OWNER/REPO` |
| GitHub subdirectory | `OWNER/REPO:PATH/TO/PLUGIN` |
| Git URL | `https://github.com/o/r.git` |
| Local path | `./my-plugin` or `/abs/path` |

`copilot plugin marketplace add` accepts the same shapes plus a **local path** —
`copilot plugin marketplace add /abs/path/to/repo` registers the repo's index in place. This is
the only way to validate a marketplace index before pushing it, and it exercises the real
resolution order and schema validation. Verified working on v1.0.80; documented in
`marketplace add --help` but not on the web docs.

`OWNER/REPO:PATH` is the imperative-install equivalent of the `path` key — it works today
and is the simplest way to install one plugin out of a monorepo.

## File Locations

| Component | Path |
|-----------|------|
| Config directory | `~/.copilot` (override with `COPILOT_HOME`) |
| Installed plugins (marketplace) | `~/.copilot/installed-plugins/MARKETPLACE/PLUGIN-NAME` |
| Installed plugins (direct) | `~/.copilot/installed-plugins/_direct/SOURCE-ID/` |
| Marketplace cache | macOS `~/Library/Caches/copilot/marketplaces/`, Linux `~/.cache/copilot/marketplaces/`, Windows `%LOCALAPPDATA%/copilot` (override `COPILOT_CACHE_HOME`) |
| User agents / skills / hooks | `~/.copilot/agents/`, `~/.copilot/skills/`, `~/.copilot/hooks/` |
| User MCP / LSP | `~/.copilot/mcp-config.json`, `~/.copilot/lsp-config.json` |
| User instructions | `~/.copilot/copilot-instructions.md`, `~/.copilot/instructions/**/*.instructions.md` |
| User settings | `~/.copilot/settings.json` |
| Repo settings | `.github/copilot/settings.json`, `.github/copilot/settings.local.json` |
| Plugin data | `${COPILOT_PLUGIN_DATA}` (aliased as `${CLAUDE_PLUGIN_DATA}`) |
| LSP path interpolation | `${PLUGIN_ROOT}` |

`config.json`, `permissions-config.json`, `session-state/`, `session-store.db`, and `logs/`
under `~/.copilot` are machine-managed — do not hand-edit.

## Loading Order and Precedence

**Agents and skills — first-found-wins** (an earlier tier silently shadows later ones):

1. Built-in (cannot be overridden)
2. User — `~/.copilot/agents/`, `~/.copilot/skills/`
3. Project — `.github/agents/`, `.github/skills/`, `.claude/`
4. Inherited — monorepo parent directories
5. Plugin — in install order
6. Remote organization / enterprise

Agents dedupe by ID (derived from filename); skills dedupe by the `name` frontmatter field.

**MCP servers — last-wins:** user config → plugin configs → `--additional-mcp-config` flag
(highest). A duplicate server name from a second plugin replaces the first, with a warning.

## Settings Priority

Built-in defaults → MDM managed settings → user `~/.copilot/settings.json` →
repository `.github/copilot/settings.json` → local `.github/copilot/settings.local.json` →
environment variables → command-line flags.

Harness-relevant keys: `enabledPlugins`, `extraKnownMarketplaces`, `strictKnownMarketplaces`
(managed only), `disableAllHooks`, `hooks`, `disabledSkills`, `skillDirectories`,
`disabledMcpServers`, `enabledMcpServers`, `subagents.agents`, `subagents.disabledSubagents`,
`sandbox.enabled`, `permissions.disableBypassPermissionsMode`, `model`, `effortLevel`,
`autoUpdate`.

## Key CLI Details

- Install: `npm install -g @github/copilot` (also Homebrew, WinGet, `curl -fsSL https://gh.io/copilot-install | bash`)
- Binary: `copilot`
- Non-interactive: `copilot -p "prompt"` (add `-s` to strip stats/decoration for piping)
- Permission flags: `--allow-all`/`--yolo`, `--allow-all-tools`, `--allow-all-paths`,
  `--allow-all-urls`, `--allow-tool=TOOL`, `--deny-tool=TOOL`, `--allow-url=URL`, `--add-dir=DIRECTORY`
- Selection flags: `--model=MODEL`, `--agent=AGENT`, `--no-ask-user`, `--secret-env-vars=VAR`
- Transcript: `--share=PATH`, `--share-gist`
- Commands: `copilot app|completion|help|init|login|mcp|plugin|skill|update|version`
- Plugin subcommands: `install`, `uninstall`, `list`, `update [--all]`, `enable`, `disable`,
  `marketplace add|list|browse|update|refresh|remove [--force]`
- Inspection: `copilot plugin list`, `copilot skill list`, `copilot mcp`
- `--plugin-dir <directory>` loads a plugin from a local directory for the session, repeatable
  — the direct equivalent of Claude's flag
- `--config-dir=DIRECTORY` overrides `~/.copilot` for a single invocation
- `-C <directory>` changes working directory before anything else
- Slash commands: `/plugin`, `/agent`, `/skills list|info|reload|add|remove`, `/instructions`,
  `/fleet`, `/autopilot`, `/model`, `/context`, `/compact`, `/diagnose`

To iterate on a local plugin, use `copilot --plugin-dir ./my-plugin` — it loads from the
directory each run, so edits are picked up without reinstalling. `copilot plugin install`
copies into `~/.copilot/installed-plugins/` instead, and that copy is a snapshot: an in-place
edit to the source directory is not picked up, so an installed plugin must be reinstalled
after every change.

Direct installs (`owner/repo`, URLs, local paths) emit a deprecation warning as of v1.0.80:
"Direct plugin installs (repos, URLs, local paths) are deprecated. Only plugin@marketplace
installs will be supported in a future release." Prefer registering a marketplace.

## Copilot Cloud Agent (vs CLI)

The cloud agent supports declarative installation only — `enabledPlugins` and
`extraKnownMarketplaces` in `.github/copilot/settings.json`. No `copilot plugin install`.
It reads hooks only from `.github/hooks/*.json` in the cloned repository.

## What Copilot CLI Supports

| Artifact | Support |
|----------|---------|
| Skills | ✓ full — plus reads `.claude/skills` and `.agents/skills` |
| Custom agents | ✓ full — `agents/*.agent.md` or `agents/*.md`, on par with Claude |
| MCP | ✓ stdio (`local`) + streamable HTTP + legacy SSE |
| Hooks | ✓ 14 events, 3 types, Claude-compatible PascalCase aliases |
| LSP | ✓ `lsp.json` / `.github/lsp.json` |
| Startup context | ✓ reads `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, and `copilot-instructions.md` natively |
| Rules | ~ modelled as `*.instructions.md` with `applyTo` globs |
| Commands | ~ `commands` manifest field exists; format undocumented — prefer skills |
| Marketplace | ✓ but see the `git-subdir` incompatibility above |

## Cross-Vendor Notes

- Copilot CLI is the most Claude-compatible of the non-Anthropic vendors: it reads
  `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.claude/skills`,
  `.claude/CLAUDE.md`, PascalCase hook event names, Claude tool names in hook matchers, and
  `${CLAUDE_PLUGIN_DATA}`. An existing Claude Code plugin usually loads unchanged.
- The exceptions that bite are all at the *marketplace index* layer, not the plugin layer:
  `git-subdir`, `archive`, and `command` source types, and non-kebab-case plugin names.
- Agent Plugins 1.0 (the Open Plugin Spec) is the emerging shared standard behind Copilot's
  format — published 2026-08-06 with AWS, Anysphere, Microsoft, OpenAI, Vercel, and Google.
  It standardises only `plugin.json` and `mcp.json` + `skills/`; everything else (agents,
  hooks, LSP) is a vendor extension. Anthropic is not listed as an adopter.

## Verified Behaviour (Copilot CLI v1.0.80, 2026-08-24)

Checked directly against the binary, not just the docs. Re-verify on version bumps — several
of these contradict the published documentation.

| Claim | Result |
|-------|--------|
| `copilot plugin marketplace add <absolute-local-path>` | ✓ works. `marketplace add --help` documents "owner/repo for GitHub, URL, or local path"; the web docs only show `owner/repo`. Registers as `Local: /abs/path`. The best way to test a marketplace index before pushing. |
| `.github/plugin/marketplace.json` wins over `.claude-plugin/marketplace.json` | ✓ confirmed. With a `git-subdir` entry present in `.claude-plugin/` only, the add succeeded and listed the Copilot index's plugins — the Claude index was never parsed. |
| `git-subdir` fails the whole index | ✓ confirmed. With `.github/plugin/` removed so it fell back: `Failed to add marketplace: Error: Invalid marketplace.json: plugins.8.source: Invalid input`, exit code 1. No plugins registered. Removing that one entry made the same file load all 8 plugins. |
| `.claude-plugin/plugin.json` resolves with no root `plugin.json` | ✓ confirmed — a plugin carrying only `.claude-plugin/plugin.json` installed and registered its skills. |
| Bare `agents/<name>.md` registers | ✓ **yes** — contrary to earlier assumption. A probe plugin with both `plain-style.md` and `suffixed-style.agent.md` registered *both*. Bare-`.md` plugin agents also ran successfully via `--agent`. |
| Agent addressing | Namespaced `plugin-name:agent-name`. A bare name is rejected with `No such agent: X, available: ...` listing the qualified names. |
| `--plugin-dir <directory>` | ✓ exists, repeatable, undocumented on the web docs. Loads from the directory each run, so edits apply without reinstalling. |
| `copilot plugins list` (plural, with `--kind`/`--scope`/`--json`) | ✗ **does not exist** in v1.0.80 — "The plugins command is not available." The real commands are `copilot plugin list` (no flags) and `copilot skill list`. The published command reference is wrong here. |
| Install output counts | Reports skills only ("Installed 12 skills"). Agents, hooks, and MCP servers are not counted — a zero-agent message does not mean agents failed to load. |
| Direct local/repo/URL installs | Work, but warn: deprecated in favour of `plugin@marketplace`. |

## Known ynh Discrepancies (as of 2026-08-24)

ynh has no Copilot adapter — Copilot is not in the vendor list, so no `plugin.json`,
marketplace index, hook config, MCP config, or instruction files are generated for it.
See references/known-gaps.md for the tracked entries.
