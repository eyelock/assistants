# Changesets

This repo uses [changesets](https://github.com/changesets/changesets) to version and release packages.

## Single source of truth

Each package's canonical manifest is:

- `.claude-plugin/plugin.json` for plugins and skills
- `.harness.json` for harnesses under `ynh/*`

`package.json` files at each workspace root are **generated mirrors** of those
manifests. The `scripts/sync-manifests.mjs` adapter handles projection in both
directions:

| Command | What it does |
| --- | --- |
| `pnpm sync-manifests` | `plugin.json` / `.harness.json` → `package.json` |
| `pnpm sync-manifests:writeback` | `package.json.version` → source manifest (post `changeset version`) |
| `pnpm sync-manifests:check` | CI gate: fail if mirrors drift |

The `preinstall` hook regenerates mirrors automatically; `changeset:version`
writes bumps back to the source manifest and re-projects.

## Adding a changeset

```sh
pnpm changeset
```

Pick the packages affected, the bump type (patch/minor/major), and write a
one-line summary. Commit the generated `.changeset/*.md` file alongside your
change.
