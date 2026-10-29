# Harness manifest

The fields of `.agents/harness/plugin.json` as this repo uses them. ynh's own documentation is the full reference; this page says which fields appear here, where, and what they do in this repo.

- [Harness manifest](https://github.com/eyelock/ynh/blob/develop/docs/harnesses.md), [Hooks](https://github.com/eyelock/ynh/blob/develop/docs/hooks.md), [MCP servers](https://github.com/eyelock/ynh/blob/develop/docs/mcp.md), [Profiles](https://github.com/eyelock/ynh/blob/develop/docs/profiles.md), [Focus](https://github.com/eyelock/ynh/blob/develop/docs/focus.md)
- The schema: `https://eyelock.github.io/ynh/schema/plugin.schema.json`

The schema requires `name` and `version`. `ynd validate` checks a manifest against it, and rejects unknown fields.

## Where manifests appear in this repo

| Place | What it is | Fields used |
|---|---|---|
| `ynh/<name>/.agents/harness/plugin.json` | A harness: a persona or a read-only platform harness | `includes`, `profiles`, `focuses`, `mcp_servers`, `hooks`, `agent`, `env_passthrough`, `keywords` |
| `plugins/<name>/.agents/harness/plugin.json` | A plugin's identity | `name`, `version`, `description`, `author` |
| `skills/<domain>/.agents/harness/plugin.json` | A skills package's identity | `name`, `version`, `description`, `author` |

Plugins and skills packages also carry `.claude-plugin/plugin.json` and `.cursor-plugin/plugin.json`. Keep the three in sync; `pnpm sync-manifests:check` gates CI. `ynh/*` harnesses are not indexed by `pnpm sync-manifests`.

## Fields

| Field | Type | Used in this repo | Notes |
|---|---|---|---|
| `$schema` | string | all | Always `https://eyelock.github.io/ynh/schema/plugin.schema.json` |
| `name` | string | all | Required. The harness or plugin id |
| `version` | string | all | Required. For plugins and packages, `changeset version` bumps it, then `pnpm sync-manifests:writeback` copies it back |
| `description` | string | all | One sentence. Platform harnesses also say they are read-only |
| `author` | object | plugins and packages | `{ "name": "eyelock" }` |
| `keywords` | string[] | platform harnesses | Search terms, for example `"read-only"` |
| `default_vendor` | string | harnesses | `claude`, `cursor`, `codex` or `copilot`. Harnesses here use `claude` |
| `includes` | object[] | harnesses | Skills to compose. See below |
| `profiles` | object | `ynh/imessage` and others | Named variants. See below |
| `focuses` | object | platform harnesses | Named `prompt` plus optional `profile`. See below |
| `mcp_servers` | object | platform harnesses | The tool a harness is given. See below |
| `hooks` | object | harnesses that must refuse something | `before_tool`, `after_tool`, `before_prompt`, `on_stop`, `on_session_start`. See [Add a hook](add-a-hook.md) |
| `env_passthrough` | string[] | harnesses with credentials | Variables the harness may see; a `${VAR}` in `mcp_servers` must be listed here |
| `agent` | object | platform harnesses | Defaults for `ynh agent run`: `max_turns`, `effort` (`low`, `medium`, `high`), also `max_tokens`, `max_wall`. Platform harnesses use `{ "max_turns": 25, "effort": "low" }` |
| `reads` | object | not used here | Declares files an artifact tells the agent to read; `ynd lint` checks they ship |
| `delegates_to`, `sensors`, `sensor_overrides` | | not used here | See ynh's documentation |

### includes

Each entry has exactly one of `git` or `local`.

| Key | Meaning |
|---|---|
| `git` | A repository URL. Harnesses here use `https://github.com/eyelock/assistants`. A local clone path also works, as in the tutorials |
| `local` | A path, absolute or relative to the harness root, that stays inside the harness |
| `path` | A directory inside the source, such as `skills/dev` |
| `pick` | Which artifacts to take: `skills/<name>` for a skill, or `agents/<name>.md`. Omit it to take everything at `path` |
| `ref` | A git tag, branch or commit (not used here: includes follow the default branch) |

A `pick` is checked by a test: `scripts/harness-picks.test.mjs` fails when a harness picks a skill that does not exist in this repo.

### profiles

A profile may hold `hooks`, `mcp_servers` and `includes`, and nothing else. It declares only what it changes.

- `mcp_servers` deep-merge; a server set to `null` is removed.
- `hooks` replace per event.
- `includes` are appended to the base ones, and cannot remove them.

`ynh/imessage` uses profiles to change one server argument: `redacted` runs `--privacy redacted` and `counts` runs `--privacy aggregate`. Select one with `--profile`.

### focuses

```json
"focuses": {
  "waiting-on-me": { "prompt": "Use the waiting-on-me skill to find what is waiting on me in Messages." }
}
```

`prompt` is required. `profile` is optional and must name a profile in the same manifest. `--focus` runs non-interactively and cannot be combined with `--profile` or a trailing prompt. Platform harnesses here carry one focus per triage question, and the list is checked by `pnpm test`; see [Triage questions](../triage/triage-questions.md).

### mcp_servers

A map of server name to either `command` (with optional `args`, `env`, `cwd`) or `url` (with optional `headers`), never both.

```json
"mcp_servers": {
  "imessage": {
    "command": "npx",
    "args": ["-y", "imessage-mcp@3.2.0", "--privacy", "full", "--contacts", "live"],
    "env": { "IMESSAGE_UPDATE_CHECK": "0", "IMESSAGE_CACHE": "0" }
  }
}
```

Pin the server's version. A `${VAR}` in `env` or `headers` needs `VAR` in `env_passthrough`, or `ynd preview` and `ynh run` reject the harness.

## Checking a manifest

```bash
ynd validate <dir>                      # schema and structure
ynd lint <dir>                          # files and frontmatter
ynd preview <dir> -v claude -o <out>    # what the assistant receives
```

The tutorials show each in use: [Build a persona harness](../personas/build-a-persona-harness.md) and [Give a harness a tool](give-a-harness-a-tool.md).
