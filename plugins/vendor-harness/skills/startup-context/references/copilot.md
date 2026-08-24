# GitHub Copilot CLI — Startup Context Reference

Docs: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions

## Files

Copilot CLI is the most permissive vendor here — it reads every major convention natively.

Repository:
- `.github/copilot-instructions.md` — repository-wide
- `.github/instructions/**/*.instructions.md` — modular, path-scoped

Agent instruction files, discovered in standard locations:
- `AGENTS.md`
- `CLAUDE.md` (also `.claude/CLAUDE.md`)
- `GEMINI.md`

User:
- `~/.copilot/copilot-instructions.md`
- `~/.copilot/instructions/**/*.instructions.md`

Override: `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` (comma-separated directory list)

**Standard discovery locations** for agent instruction files: the repository root, the
current working directory, every intermediate directory between them, and directories nested
along the path of files being worked on.

## No @AGENTS.md Bridge Needed

Claude Code does not read `AGENTS.md`, which is why ynh exports a `CLAUDE.md` containing only
`@AGENTS.md`. Copilot reads **both** files directly, so no bridge is required.

The bridge is harmless if present: Copilot removes duplicate copies of identical
user-level `copilot-instructions.md`, repository-wide, and agent instructions. A `CLAUDE.md`
whose only content is `@AGENTS.md` expands to the same text as `AGENTS.md` and is deduped.

## @-Import Syntax

Supported in `.github/copilot-instructions.md`, `AGENTS.md`, and `CLAUDE.md`:

```
@path/to/file.md
```

- The referenced file is read immediately, and references inside referenced files also resolve.
- Paths must stay inside the repository or the custom-instructions directory.
- Absolute paths and `~/` paths are **not** loaded.
- Imports do **not** expand in `GEMINI.md` or in `*.instructions.md` files.

## Path-Scoped Instructions — Copilot's "rules"

`*.instructions.md` files are the closest analogue to Cursor's `.mdc` rules:

```markdown
---
applyTo: "src/**/*.py,tests/**/*.py"
excludeAgent: "code-review"
---

- Prefer small, focused changes
```

- `applyTo` — glob(s), comma-separated. `*` matches within a directory, `**` / `**/*`
  recursive. The instruction activates only when the pattern matches the file in play.
- `excludeAgent` — restricts usage; documented values include `code-review` and `cloud-agent`.

Contrast with Cursor: `.mdc` extension + `description`/`globs`/`alwaysApply`. Copilot uses
`.instructions.md` + `applyTo`. Neither reads the other's format.

## Combination and Precedence

Copilot **combines** all applicable files rather than picking a winner. It deduplicates
identical user-level `copilot-instructions.md`, repository-wide, and agent instructions, but
**does not define a general precedence order** between these files. Do not rely on one file
overriding another — if two files disagree, both reach the model.

Path-specific instructions are included only when their `applyTo` glob matches. Files
disabled through `/instructions` are excluded.

## Diagnostics

- `/instructions` lists every instruction file that loaded and lets you toggle them — the
  fastest way to confirm whether a file was picked up.
- `copilot init` scaffolds custom instructions for a repository.
- `copilot plugin list` shows installed plugins (it does not itemise instruction sources).
- An import that silently produced nothing is almost always an absolute or `~/` path, or a
  path escaping the repository.

## Cross-Vendor Mapping

| Vendor | Primary file | Path-scoped rules |
|--------|-------------|-------------------|
| Claude Code | `CLAUDE.md` | `.claude/rules/*.md` |
| Cursor | `.cursor/rules/*.mdc` | `.cursor/rules/*.mdc` (`globs` frontmatter) |
| Codex | `AGENTS.md` | not supported |
| Copilot CLI | `AGENTS.md` / `CLAUDE.md` / `.github/copilot-instructions.md` | `.github/instructions/**/*.instructions.md` (`applyTo`) |

Writing `AGENTS.md` satisfies Codex and Copilot at once; only Claude and Cursor need
vendor-specific files.
