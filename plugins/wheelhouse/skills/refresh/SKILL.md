---
name: refresh
description: Apply merged Wheelhouse changes after a pull - works out from the git diff which seats to reinstall (ynh install), which seats ynh no longer counts as trusted (any change to a seat's sensors, hooks, MCP servers, workspace or focuses) and need the human to run ynh trust accept local/<seat>, and which seats to restart, runs the safe steps, then the doctor. Also checks every roster seat is installed and born, and offers ynh update when a seat's cached wheelhouse plugin is behind upstream. The desk's skill. Use after the human pulls the Wheelhouse repository, when the CI watcher reports merges to it, or when asked what needs reinstalling or restarting.
allowed-tools: Bash Read
---

# Refresh

Merged changes don't reach the running seats by themselves. A seat is an installed ynh harness,
so a changed charter, roster or desk skill needs `ynh install`; a change to a seat's sensors, hooks,
MCP servers, workspace or focuses leaves it not accepted, and it loses its workspace folders until
the human runs `ynh trust accept local/<seat>`; a changed script needs a restart. `refresh.sh` works out which,
from the diff, so nobody has to remember the sequence.

This is the desk's skill, and no other seat's. The desk runs it whenever the human pulls, or when
the CI watcher reports merges to the Wheelhouse repository itself.

Run it from the Wheelhouse's root, by the path ynh installed it at (`<skills>` is the folder that holds the skill folders: the parent of this skill's base directory), with `--dir` pointing at the Wheelhouse repository (the one with
the desk's `.agents/harness/` and `.beads/`), after the pull:

```bash
bash <skills>/refresh/scripts/refresh.sh --dir . --dry-run   # what it would do
bash <skills>/refresh/scripts/refresh.sh --dir .             # do the safe steps
```

## What the diff means

It reads `git diff --name-only <from>..<to>`, by default `ORIG_HEAD..HEAD`, which is what the pull
just moved. After anything else that moved `ORIG_HEAD` since the pull, give the range:
`--from <old> --to <new>` or `<old>..<new>`.

| Path | Needs |
|---|---|
| `harnesses/<seat>/...` | `ynh install harnesses/<seat>` |
| the root `AGENTS.md`, the root `.agents/harness/plugin.json`, `skills/roster/...` | `ynh install .` and every seat (they include `../..`) |
| another `skills/<name>/...` | `ynh install .`, and each seat whose `../..` include picks that skill |
| a change to a harness's workspace, sensors, hooks or MCP servers (top level or in any profile, and a profile's `includes`), launch focus (its name, and the profile and prompt of that entry in `focuses`) or `delegates_to` entries in its `plugin.json`, or a seat ynh lists as `changed` or `unreviewed` after the installs | **printed** `ynh trust accept local/<seat>`, never run |
| `scripts/...` (the Wheelhouse's own) | a restart of every seat: hooks run them from disk, and a running session keeps the old ones |
| anything else, such as `docs/` or a `pinned-skills.md` | nothing |

A seat folder that is gone is reported with `ynh uninstall local/<seat>` and not run.

Trust is asked of ynh, not inferred: after the installs (and any `--update`) it reads
`ynh trust ls --format json` and lists every roster seat whose state is `changed` or `unreviewed`,
whatever the cause, including a wheelhouse plugin update that changed a hook. The diff's changes to
those fields are listed too, because a `--dry-run` installs nothing and so can't see the state
afterwards; it says so in `notes`. What the diff cannot see, only `ynh trust ls` does: the prompt of a delegate's focus (it lives in the
delegate's own harness, so a changed prompt shows only after the installs), and anything an include
brings in from the included harness.

A seat ynh lists as `unavailable` (what it runs could not be read in full, usually an include that
isn't cached) is reported in `notes` with the problems ynh gives. It loses its workspace folders, and
`ynh trust accept` does not fix it: `ynh update local/<seat>` fetches the include, and then refresh
is run again.

## With no diff

When the diff is empty, or with `--upstream`, it also compares each seat's cached `wheelhouse`
include with upstream (`ynh ls --check-updates`) and lists the `ynh update local/<seat>` each one
needs. `--update` runs them, and the seats it updates are listed to restart. Refresh copies no script: a Wheelhouse
keeps none of the plugin's scripts, and seats run them where ynh installed them, so `ynh update` is the whole way a fix reaches a seat.
A copy left in `scripts/` by an older Wheelhouse is a fork the update never reaches; the doctor warns about each, and the fix is to delete it. Ask before `--update`: it changes what the seats run.

## What it prints

One JSON object. `--dry-run` fills `install`, `trust`, `restart` and the rest, and runs nothing.

- `install`, `ran`: the installs planned, and each one run with its outcome. A failed install
  doesn't stop the rest; `failed` is true and the exit code is 3.
- `trust`: `ynh trust accept local/<seat>` commands for the human to run themselves. `ynh trust accept` records that they read what
  the harness executes; a seat doing it for them defeats it.
- `restart`: the seats to restart, so the new install and scripts take effect.
- `seatsNotReady`: any roster seat not installed (with the exact `install` command) or not born
  (a pinned identity in `seat/<command>`, read from ynm or, when `wheelhouse.json`
  says `"memory": "beads"`, from Beads through `memory.sh`). A seat's birth is its roster entry's `seated-by`
  first; a seat with none falls back to the dispatcher when it is a worker, else the human. The entry's
  `reminder` says which.
  Install it for the human to run, don't birth it.
- `upstream`: `updates`, each `{seat, installed, available, command}`.
- `doctor`: the `doctor` skill's `ok` and its failing checks, run after the installs.
- `notes`: what it couldn't do, such as no `ynh` on `PATH`.

## Reporting

Lead with whether anything needs doing. Then, in the order the human acts: the `trust` commands
(they come first, since a restart before the trust starts the seat without its new folder); the
seats to restart; the seats not installed or born; the doctor's failures. Name nothing the report
doesn't list, and never run `ynh trust accept`.
