---
name: patrol
description: Patrol a Wheelhouse's repositories - pull requests, issues and CI - with scripts/patrol.sh, which compares them with the last patrol and prints only what changed (merged, closed, draft or ready, retargeted, conflicting, new, CI red or green again), so a CI-watcher seat on a 5-minute timer is woken only when there's news. Use when asked to patrol, to watch pull requests or CI, to report what changed since last time, or to set up a patrol timer.
allowed-tools: Bash Read
---

# Patrol

Watching is a script's job, not a model's. `scripts/patrol.sh` reads each repository's open and
recently closed pull requests and issues, and its CI, with `gh`; compares them with the snapshot
the last patrol left; prints what changed as a JSON list; and saves the new snapshot. It costs a
few `gh` calls and no tokens, so it can run every 5 minutes, and a seat is woken only when the
list isn't empty.

Run it from the Wheelhouse root, where `create-wheelhouse` copies it (with its two `.jq` files)
into `scripts/`:

```bash
bash scripts/patrol.sh
```

## What it reads

- **Repositories:** each `--repo <owner/name>`; else `$WHEELHOUSE_REPOS` (space-separated); else
  the Wheelhouse's own GitHub remote and that of each checkout the constitution names under
  "What it reaches" as a relative path in backticks, such as `` `../api` ``.
- **Per repository:** the most recent pull requests and issues, open or closed (`--limit`,
  default 30): their state, draft, base branch, merge state and the CI on each open pull
  request's head; and the latest run of each workflow on the default branch.
- **The snapshot:** `.wheelhouse/patrol.json`, in a folder that ignores itself in git, or
  `--snapshot <file>`, such as a file in the seat's scratchpad. The first run only saves it and
  prints `[]`. A repository added later starts as a baseline too.

## What it prints

`[]` and exit 0 when nothing changed. Otherwise one object per change, `{kind, repo, number,
title, url}` plus what the kind needs:

| kind | when |
|---|---|
| `pr-opened` | a new pull request (`draft`, `base`) |
| `pr-merged` | merged, with `method`: `merge` (a merge commit) or `squash` (one parent; a rebase merge reads the same) |
| `pr-closed`, `pr-reopened` | closed unmerged, or opened again |
| `pr-draft`, `pr-ready` | moved to draft, or marked ready for review |
| `pr-retargeted` | its base branch changed (`from`, `to`) |
| `pr-dirty` | it now conflicts with its base (merge state `DIRTY`) |
| `pr-ci-red`, `pr-ci-green` | its checks failed, or passed again after failing |
| `issue-opened`, `issue-closed`, `issue-reopened` | an issue's state changed (`reason` on close) |
| `ci-red`, `ci-green` | the default branch's CI failed, or passed again (`branch` instead of `number`) |
| `error` | `gh` couldn't read a repository (`detail`); exit 3 |

A repository `gh` can't read keeps its last snapshot, so what happened meanwhile is reported once
`gh` reads it again, never lost and never twice. `--dry-run` prints the changes without saving the
snapshot.

## Running it every 5 minutes

Pick one; the human chooses, since each runs on their machine or account:

- **In a running session,** with the vendor's background watch (in Claude Code, the Monitor
  tool), a loop that prints only news, so each change list is one event:

  ```bash
  while true; do
    out=$(bash scripts/patrol.sh 2>&1)
    [ "$out" = "[]" ] || echo "$out"
    sleep 300
  done
  ```

- **cron, or launchd on a Mac,** waking the seat only when there's news. The timer peeks with
  `--dry-run`, and the seat's own patrol saves the snapshot:

  ```bash
  */5 * * * * cd <the Wheelhouse root> && [ "$(bash scripts/patrol.sh --dry-run 2>/dev/null)" != "[]" ] && <command> --focus patrol
  ```

  On a Mac, a launchd agent with `StartInterval` 300 runs the same command line.
- **A scheduled routine** in the vendor's cloud, where one exists, running the seat's patrol
  focus every 5 minutes. It needs the repositories and `gh` there, and acts only on a non-empty
  list.

## Acting on the list

Report each change to the desk, one line each, naming the pull request or issue by its short form
as a Markdown link (`[api #12](https://github.com/<owner>/api/pull/12)`), and say how a merged
one was merged. The humans don't announce merges; the patrol does. File work for what needs it as
the CI watcher's charter says (a red CI, a conflicting pull request), skipping what an open bead
already covers. An `error` is reported too: a patrol that can't see is not a quiet one.
