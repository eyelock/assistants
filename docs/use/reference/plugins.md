# Plugins

Everything the marketplaces list. Two kinds: plugins in `plugins/`, which also carry agents and
hooks, and skill packages in `skills/`, which hold skills only. Skills are listed in
[Skills](skills.md). Versions are from `.claude-plugin/marketplace.json`.

## Plugins (`plugins/`)

| Plugin | Version | Skills | Agents | Hooks |
|---|---|---|---|---|
| `gitflow` | 0.2.0 | 6 | 1 | none |
| `media-management` | 0.3.0 | 11 | 2 | yes: `SessionStart` config check, `PreToolUse` bash validation and auto-approval |
| `vendor-harness` | 0.3.0 | 12 | 4 | none |
| `wheelhouse` | 0.1.0 | 8 | none | none |

### gitflow

Gitflow branching, conventional commits, a build-lint-format-test gate, tag-driven release, and
push and PR workflow.

- Skills: `branching`, `ci`, `commits`, `push`, `quality-gate`, `release`.
- Agent: `reviewer` (runs the quality gate and reports correctness issues).
- Used by the `termq-dev` and `ynh-dev` personas.

### media-management

Processes music purchases and audio CDs into Apple Music and a NAS.

- Skills: `archive-media`, `audit-release`, `cleanup`, `import-to-apple-music`, `manage-metadata`,
  `process-album`, `reclaim-space`, `rip-cd`, `select-release`, `setup`, `split-long-tracks`.
- Agents: `media-analyst`, `metadata-checker`.
- Hooks: `hooks/hooks.json` runs `check-config-session.sh` at session start and
  `validate-bash-command.sh`, `gate-config-required-skills.sh` and auto-approval scripts before
  tool calls. These are Claude Code hooks.
- Paths come from environment variables or a `config.json`: `MEDIA_MGMT_DOWNLOADS`,
  `MEDIA_MGMT_PROCESSED`, `MEDIA_MGMT_LIBRARY_IMPORT`, `MEDIA_MGMT_LIBRARY_STORAGE`,
  `MEDIA_MGMT_ARCHIVE_WORKDIR`, `MEDIA_MGMT_WORK_DIR`, `MEDIA_MGMT_REKORDBOX_MCP_PATH`,
  `MEDIA_MGMT_CD_READ_OFFSET`, and `MEDIA_MGMT_CONFIG_PATH` for the config file. Run the `setup`
  skill to check them.

### vendor-harness

Lifecycle management for harness artifacts across Claude Code, Cursor, Codex and Copilot CLI.

- Skills: `compose-feedback`, `fetch-vendor-docs`, `flag-vendor-gaps`, `hooks-artifact`,
  `locate-artifact-source`, `mcp-artifact`, `plugin-audit`, `skill-artifact`, `startup-context`,
  `subagent-artifact`, `submit-feedback`, `vendor-adapters`.
- Agents: `harness-advisor` (entry point), `feedback-composer`, `provenance-detective`,
  `vendor-sync`.

### wheelhouse

A Wheelhouse: named agent seats for one space of work, each a ynh harness, sharing a Beads work
graph and ynm memory.

- Skills: `add-seat`, `birth`, `create-wheelhouse`, `doctor`, `handoff`, `kudos`, `wake`, `work-graph`.
- Seats are born once, in their own words, and wake every session with purpose: `scripts/wake.sh`
  runs from each seat's session-start hook.
- Needs `ynh`, `ynm` and Beads (`bd`). The `doctor` skill checks they are set up right.
- Walk through one in [Build a Wheelhouse](../../build/tutorials/build-a-wheelhouse.md).

## Skill packages (`skills/`)

| Package | Marketplace name | Skills | Domain |
|---|---|---|---|
| `skills/dev` | `dev-skills` | 9 | development workflow |
| `skills/tech` | `tech-skills` | 4 | languages |
| `skills/infra` | `infra-skills` | 2 | infrastructure |
| `skills/pause` | `pause-skills` | 2 | conversational alignment |
| `skills/triage` | `triage-skills` | 8 | triage |
| `skills/platforms` | `platform-skills` | 6 | platform reading |
| `skills/voice` | `voice-skills` | 5 | writing voice |

The marketplace also lists `ynh`, which is not part of this repository: it points at
`eyelock/ynh`.

## Which vendors each supports

Every plugin and package has a `.claude-plugin/plugin.json`, a `.cursor-plugin/plugin.json` and a
`.agents/harness/plugin.json` (for ynh). `vendor-harness` also has a `.codex-plugin/plugin.json`.
Copilot CLI uses the Claude manifest.

| Tool | Reads | Install |
|---|---|---|
| Claude Code | `.claude-plugin/` | [Install a plugin](../tutorials/install-a-plugin.md) |
| Cursor | `.cursor-plugin/` | [Install in Cursor and Copilot](../how-to/install-in-cursor-and-copilot.md) |
| GitHub Copilot CLI | `.github/plugin/marketplace.json`, `.claude-plugin/plugin.json` | same |
| ynh (Claude Code, Codex, Copilot, Cursor) | `.agents/harness/` | [Run a persona](../tutorials/run-a-persona.md) |
| Codex | skills copied to `~/.agents/skills`; `.codex-plugin/` for `vendor-harness` only | `README.md` |

Skills load natively in all four tools. Agents and hooks do not carry across all of them: the
`vendor-adapters` skill holds the support matrix. `README.md` also names a Codex marketplace at
`.agents/plugins/marketplace.json`; that file is not on this branch.
