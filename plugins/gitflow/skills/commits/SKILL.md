---
name: commits
description: Conventional commit message format, PR description template, and PR title conventions.
---

# Commits

## Commit Message Format

Use Conventional Commits:

```
<type>(<scope>): <subject>

<body — explain WHY, not WHAT>

<attribution trailer, if any>
```

**Types:** `feat` `fix` `refactor` `docs` `test` `ci` `build` `perf` `style` `chore`

- `build` — build system, packaging or dependency changes
- Release housekeeping (release PR titles, CHANGELOG and version bumps) uses `chore` with the `release` scope: `chore(release): v1.4.0`

**Scopes (optional):** use a short noun that identifies the affected area — e.g. `api`, `auth`, `cli`, `ui`, `deps`, `db`

**Subject:** a capitalized imperative ("Add pagination", not "add pagination" or "Added pagination"), with no trailing period.

**Attribution:** when an AI tool wrote the commit, end the message with the attribution trailer that tool provides (Claude Code supplies the right `Co-Authored-By:` line) — never copy a hard-coded one. When a human wrote the commit, add none.

Pass via HEREDOC to avoid quoting issues:

```bash
git commit -m "$(cat <<'EOF'
feat(api): Add pagination to list endpoints

List endpoints were returning unbounded result sets, causing
timeouts on large datasets.

<attribution trailer from your AI tool, if any>
EOF
)"
```

## Breaking Changes

Mark a breaking change with `!` after the type (and scope), and add a `BREAKING CHANGE:` footer that says what breaks and how to migrate:

```
feat(cli)!: Remove the --out flag

Writing to a file belongs to the shell, and --out duplicated it
with its own bugs around relative paths.

BREAKING CHANGE: --out and -o are gone. Redirect stdout instead.
```

Pair a breaking commit with a `major` changeset (or a major version bump if the project does not use changesets).

## PR Description Template

```markdown
## Summary
Brief overview of changes and why.

## Changes
- Change 1
- Change 2

## Testing
- [ ] Quality gate passes
- [ ] Manual testing completed

## Related Issues
Fixes #123

<the attribution line your AI tool provides for PRs, if any>
```

## PR Title

Same format as a commit message, including the subject rule and any `!`: `feat(scope): Brief description`
