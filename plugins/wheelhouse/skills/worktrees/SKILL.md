---
name: worktrees
description: Make, find and remove a seat's git worktrees where the Wheelhouse says they go, with scripts/worktree.sh, never at a path the seat invents. add makes a worktree for a branch at the Wheelhouse's policy path (worktrees.json beside tracker.json; the scratchpad when there is none), prints the path and notes it on the bead; list shows every worktree of every repository the Wheelhouse reaches with its seat, repo, branch and bead and flags the stale ones; remove takes one away safely. Use when a seat needs to work on or test a branch without touching a shared checkout, to find a worktree, or to clean up after a merge.
allowed-tools: Bash Read
---

# Worktrees

A shared checkout is never changed: no switching branches, no commits, no stash. To work on or test
a branch, a seat uses its own worktree. Where it goes is the Wheelhouse's decision, not the seat's:
a scratchpad is temporary and per session, so a worktree left there is lost. `scripts/worktree.sh`
(in this skill's folder, where ynh installed it) makes the path, so never type one yourself.

Run it from the Wheelhouse root, or pass `--dir`. It finds the checkouts the constitution
(`AGENTS.md`) names under "What it reaches" as `../<name>`, or take `--repo-path <name>=<dir>`.

## Make a worktree

```bash
path=$(bash <skills>/worktrees/scripts/worktree.sh add --seat <you> --repo <repo> --branch <branch> --bead <id>)
cd "$path"
```

- It prints the absolute path and nothing else, so capture it. Work in that path only.
- An existing branch is checked out. A new branch must start with `<you>/` (a seat creates only its
  own prefixed branches) and is cut from `--base`, default `origin/develop`, else `origin/main`:
  fetch first.
- `--bead` appends the line `Worktree: <path>` to the bead's notes as you, which is how `list` finds the bead
  and how the dispatcher knows the worktree is finished when the bead closes. Always give it.

## Find worktrees

```bash
bash <skills>/worktrees/scripts/worktree.sh list [--repo <name>] [--stale]
```

A JSON list of `{seat, repo, branch, bead, path, stale, why}` over every repository the Wheelhouse
reaches. `stale` is true when the bead is closed, or the branch is merged (its upstream gone after a
merge). `--stale` keeps only those.

## Remove a worktree

```bash
bash <skills>/worktrees/scripts/worktree.sh remove <path> --seat <you>
```

- You may remove your own worktrees. The dispatcher (the default cleaner built into
  `worktree.sh`, or a seat named in `$WORKTREE_CLEANERS`) may remove any seat's whose bead is closed; a worker need not tidy.
- It refuses a path outside the policy layout, a worktree with uncommitted work, and any other
  seat's whose bead is open. Commit or discard the work yourself; the script never forces.
- It never runs `worktree prune`, `move`, `lock` or `repair`, and never `--force`; neither do you.
  Never use `git stash`: every worktree of a repository shares one stash list. To set work aside,
  commit it to a throwaway branch in your worktree.

## The policy

`worktrees.json` in the Wheelhouse root:

```json
{"layout": "{repo}/.worktrees/{seat}/{branch}"}
```

`{repo}` is the repository's name, `{seat}` the seat's command, `{branch}` the branch (a slash is
kept: `feat/x` is `.../feat/x`), `{scratchpad}` the scratchpad (`$WORKTREE_SCRATCHPAD`, else
`${TMPDIR:-/tmp}/worktrees`). A relative layout starts at the folder that holds the checkouts, so
the example puts a worktree in `<checkout>/.worktrees/<seat>/<branch>`. With no file the layout is
`{scratchpad}/{repo}/{branch}`. A layout inside a checkout needs `.worktrees/` in that repository's
`.gitignore`; `git check-ignore .worktrees` says. Without `{seat}` in the layout a worktree's owner
cannot be told, so any seat may remove one.
