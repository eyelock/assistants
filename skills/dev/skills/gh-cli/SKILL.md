---
name: gh-cli
description: GitHub operations via gh CLI — use this instead of GitHub MCP server tools for all PR, issue, release, and CI work.
---

# GitHub via gh CLI

**Always use `gh` CLI for GitHub operations. Never use GitHub MCP server tools.**

The `gh` CLI is always available, scriptable, and produces predictable output. MCP server tools introduce unnecessary indirection and cause confusion when their side effects (push, create, close) occur even if you later reject the agent's response.

## Read Freely, Write Only When Asked

Reads change nothing: `list`, `view`, `checks`, `diff`, `status`, `search`, `run view`, and `gh api` GETs. Run as many as the question needs.

Writes change what other people see: `create`, `comment`, `edit`, `merge`, `close`, `review`, `run rerun`, `release delete`, and `gh api` with `-X POST`, `PATCH`, `PUT` or `DELETE`. Run one only when the user asked for that change. When a read turns up something worth doing (a rerun, a comment, a merge), report it and offer; don't do it.

For scripting, ask for `--json <fields>` and filter with `--jq` rather than parsing the table output.

## What's Waiting on Me

`gh pr list` only covers the current repository; review requests and assigned issues can live anywhere.

```bash
gh status                                            # assigned issues and PRs, review requests, mentions, across repos
gh pr list --author @me                              # my open PRs here
gh search prs --review-requested=@me --state=open    # PRs waiting on my review, every repo
gh issue list --assignee @me
```

Report each PR with what blocks it: failing checks, review required, draft, or ready to merge.

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

### Why Did CI Fail?

Go from the PR to the failing step's output, then read the code it points at:

```bash
gh pr checks <number>                  # which check failed; its link holds the run and job IDs
gh run view <run-id>                   # the run's jobs and the failed step
gh run view <run-id> --log-failed      # only the failed steps' log
gh run view <run-id> --job <job-id> --log   # one job's full log, when the failed lines need context
```

An aggregate check (such as All Clear) fails because another job did: report the job that actually failed. Rerunning is a write: suggest it for a failure that looks flaky, and run it only when asked.

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
