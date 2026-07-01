---
name: setup
description: >-
  Check that all media-management paths (Downloads, Apple Music, NAS archive,
  rekordbox-mcp) are resolvable via env var or config.json, and help the user
  fix any that are missing. Use when paths seem not configured, when a skill
  fails to resolve a path, when explicitly asked to set up/configure the
  plugin, or when asked where its config lives or how path resolution works.
allowed-tools: Bash Read Write
metadata:
  author: eyelock
  version: "0.1.0"
---

## Setup

Scripts are in `scripts/` relative to this skill directory.

## Step 1: Check current configuration

Run:
```bash
bash scripts/check-config.sh
```

This returns JSON with `config_path`, `config_exists`, `items` (one entry per key,
each with its `env_var`, whether it's `required`, the resolved `value`, and
`source`: `env`, `config`, or `missing`), and `missing_required` (keys with no
value from either source).

## Step 2: If nothing is missing

If `missing_required` is empty, report a status table and stop. The Source column
must say exactly where the value came from, not just `env` or `config`:

- If `source` is `env`, show the actual env var name, e.g. `env: MEDIA_MGMT_DOWNLOADS`.
- If `source` is `config`, show the config file path, e.g. `config: ~/.config/media-management/config.json`.

| Key | Value | Source |
|-----|-------|--------|
| downloads | /Users/david/Downloads | env: MEDIA_MGMT_DOWNLOADS |
| library_import | ... | config: ~/.config/media-management/config.json |

Mention that `rekordbox_mcp_path` is optional — it's only needed for the
`rekordbox-database` MCP tools — and if it's missing, note that in passing
without treating it as a problem.

## Step 3: If required keys are missing

Present the missing keys to the user, one at a time, asking for the absolute path
for each:

- `downloads` — where their purchased ZIPs land (e.g. `~/Downloads`)
- `library_import` — the Apple Music auto-import folder. If the user isn't sure,
  suggest they run:
  ```bash
  find ~ -name "Automatically Add to Music.localized" -type d 2>/dev/null
  ```
- `library_storage` — the Apple Music library location (e.g. `~/Music`)
- `archive_workdir` — the NAS/archive staging directory

Expand `~` to the user's home directory before saving. Confirm each value back to
the user before moving to the next.

## Step 4: Write config.json

Once all missing required values are collected, merge them into the existing
config (if `config_exists` was true, read it first and preserve any keys not
being updated) and write the result to `config_path` (creating the parent
directory if needed) using the Write tool. Use this shape:

```json
{
  "downloads": "...",
  "library_import": "...",
  "library_storage": "...",
  "archive_workdir": "...",
  "processed": "...",
  "rekordbox_mcp_path": "..."
}
```

Omit keys the user didn't provide and that weren't already present.

## Step 5: Mention the environment variable alternative

Let the user know they can skip config.json entirely by exporting the
corresponding `MEDIA_MGMT_*` env var (see `env_var` in the Step 1 output) in
their shell profile instead — env vars always take priority over config.json.

**Special case — `rekordbox_mcp_path`:** this one is read directly by
`.mcp.json` when Claude Code launches the `rekordbox-database` MCP server, and
`.mcp.json` can only substitute environment variables, not `config.json`
values. Writing it to `config.json` is still useful for bookkeeping, but if the
user wants the rekordbox tools to actually work, they must also
`export MEDIA_MGMT_REKORDBOX_MCP_PATH=...` in their shell profile and restart
their terminal / Claude Code session.
