# Install in Cursor and Copilot

Use this repository's plugins and skills in Cursor or GitHub Copilot CLI. To install in Claude
Code, follow [Install a plugin](install-a-plugin.md).

The repository carries one marketplace index per tool, kept in step by `pnpm sync-manifests`:
`.cursor-plugin/marketplace.json` for Cursor and `.github/plugin/marketplace.json` for Copilot.

## GitHub Copilot CLI

Add the marketplace, then install a plugin from it:

```bash
copilot plugin marketplace add eyelock/assistants
copilot plugin install gitflow@eyelock-assistants
copilot plugin list
```

Run in a scratch `HOME`, this printed `Marketplace "eyelock-assistants" added successfully.`,
`Plugin "gitflow" installed successfully. Installed 6 skills.` and
`gitflow@eyelock-assistants (v0.2.0)`.

To install one plugin without adding the marketplace:

```bash
copilot plugin install eyelock/assistants:plugins/vendor-harness
```

> Not run: this form. It is the command in the repository `README.md`.

To copy a single skill instead of a plugin (Copilot reads `~/.copilot/skills`), from a clone of the
repository:

```bash
cp -r skills/dev/skills/dev-project ~/.copilot/skills/
```

> Not run: the copy.

Copilot rejects a whole marketplace index over one unsupported source type, which is why its index
is a separate file. See `plugins/vendor-harness/skills/vendor-adapters/references/copilot.md`.

## Cursor

How you install depends on your plan.

- **Teams or Enterprise.** Import this repository as a team marketplace under Dashboard,
  Settings, Plugins. Team members then install from the plugin manager.
- **Individual.** Cursor has no custom marketplace for individuals. Copy a plugin from a clone of
  the repository to the local plugins folder:

  ```bash
  mkdir -p ~/.cursor/plugins/local
  cp -R plugins/gitflow ~/.cursor/plugins/local/
  ```

> Not run: any Cursor step. Both come from the repository `README.md`; the `mkdir` line and the
> choice of `plugins/gitflow` as the example are added here. Each plugin has its own
> `.cursor-plugin/plugin.json`.

## What works where

Skills (`SKILL.md`) load natively in Claude Code, Cursor, Codex and Copilot. Plugin hooks and
agents differ by tool. `media-management` ships Claude Code hooks, so its safety checks and
auto-approval apply in Claude Code. For a per-vendor view, see
[Plugins](plugins.md) and the `vendor-harness` plugin's `plugin-audit` skill.
