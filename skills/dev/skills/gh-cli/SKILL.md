---
name: gh-cli
description: GitHub operations via gh CLI — use this instead of GitHub MCP server tools for all PR, issue, release, and CI work.
---

# GitHub via gh CLI

**Always use `gh` CLI for GitHub operations. Never use GitHub MCP server tools.**

The `gh` CLI is always available, scriptable, and produces predictable output. MCP server tools introduce unnecessary indirection and cause confusion when their side effects (push, create, close) occur even if you later reject the agent's response.

## Pull Requests

```bash
gh pr create --base <branch> --title "<title>" --body "<body>"
gh pr list
gh pr view <number>
gh pr view <number> --comments
gh pr checks <number>
gh pr checks <number> --watch
gh pr merge <number> --squash
gh pr edit <number> --base <branch>
gh pr close <number>
```

## Issues

```bash
gh issue list
gh issue view <number>
gh issue create --title "<title>" --body "<body>"
gh issue comment <number> --body "<body>"
gh issue close <number>
gh issue edit <number> --add-label "<label>"
```

## CI / Workflow Runs

```bash
gh run list --workflow=<name>.yml --limit 5
gh run view <run-id>
gh run watch <run-id>
gh run watch <run-id> --exit-status    # blocks until complete; exits non-zero on failure
gh run list --branch <branch> --workflow=ci.yml --limit 1
gh run list --commit <sha> --workflow=ci.yml
```

## Releases

```bash
gh release list
gh release view v{VERSION}
gh release delete v{VERSION} --yes
```

## Branches and Repos

```bash
gh repo view
gh repo clone <owner>/<repo>
gh api repos/{owner}/{repo}/branches    # when gh doesn't have a direct command
```

## Passing Multi-line Bodies

Always use a HEREDOC to avoid quoting issues:

```bash
gh pr create --base develop --title "feat: my feature" --body "$(cat <<'EOF'
## Summary
- Did the thing

## Testing
- [ ] make check passes
EOF
)"
```
