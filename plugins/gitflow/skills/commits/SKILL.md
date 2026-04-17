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

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

**Types:** `feat` `fix` `refactor` `docs` `test` `ci` `perf` `style` `chore`

**Scopes (optional):** use a short noun that identifies the affected area — e.g. `api`, `auth`, `cli`, `ui`, `build`, `db`

Pass via HEREDOC to avoid quoting issues:

```bash
git commit -m "$(cat <<'EOF'
feat(api): Add pagination to list endpoints

List endpoints were returning unbounded result sets, causing
timeouts on large datasets.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

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

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## PR Title

Same format as a commit message: `feat(scope): Brief description`
