---
name: doctor
description: Check a Wheelhouse is set up right - ynm installed and healthy, with a distributed mount in the Wheelhouse repository and registered with ynh, Beads installed with a work graph and none of its own agent setup, shared through the repository's remote, and the humans: one default human, and every bead assigned to someone in the roster or to a seat on trial (its harness on the checked-out branch). Use when asked to check, validate or diagnose a Wheelhouse, its memory or its work graph, after creating one, or when a seat finds ynm or bd missing or misbehaving.
---

# Doctor

Run `<skills>/doctor/scripts/check.sh` from this skill's folder, with `--dir` pointing at the Wheelhouse
repository (the one with the desk's `.agents/harness/` and `.beads/`). From the Wheelhouse root:

```bash
bash path/to/doctor/scripts/check.sh --dir .
```

`check.sh` calls `scripts/memory-checks.sh` for the checks that depend on the memory backend.

It prints JSON: `ok`, and one entry per check with `name`, `ok`, `level`, `detail` and `fix`. It
changes nothing. `ok` is false when any check has level `error`.

## Where the scripts are

The plugin's scripts are not copied into the Wheelhouse: they run where ynh installed them, in the `scripts/` folder
of the skill that owns each. `<skills>` below is the folder that holds the skill folders, the parent of this
skill's base directory (the wake skill says more). Run them from the Wheelhouse's root.

## What it checks

| Check | Why it matters |
|---|---|
| memory backend | `wheelhouse.json`'s `memory` key (`ynm`, or `beads`; ynm when there is none), read through `memory.sh`. The ynm checks below run for ynm only; a Beads Wheelhouse needs no ynm. A key that is neither is an error (and so is a `wheelhouse.json` naming a backend when no `memory.sh` exists anywhere to read it) |
| plugin script memory.sh, inbox.sh | the work-graph skill's scripts, beside this skill where ynh installed them: `memory.sh` (how `wake.sh`, `inbox.sh` and the skills read and write memory for either backend) and `inbox.sh` (how seats ask the humans for things and how the desk's wake shows their inbox). An error when one is missing: the seat that runs the doctor has no work-graph skill, so its wake, inbox and memory stop (exit 3). The fix is to add `skills/work-graph` to the seat's `pick`. The memory backend row errors only for an unreadable or unknown `memory` key |
| plugin script copies | a Wheelhouse keeps none of the plugin's scripts, so a `scripts/` file with the name of one is a copy the plugin's fixes never reach. A warning naming each; delete it, and point hooks and docs at the installed script |
| beads memory readable (Beads memory) | `bd --readonly memories --json` must parse: seats keep their identity, handoff notes and Kudos there. An error when it doesn't |
| beads memory shared (Beads memory) | memory shares through the work graph's Dolt remote; a warning without one, as memory then stays on this machine |
| ynm installed (ynm memory) | seats keep their memory, handoff notes and Kudos in ynm |
| errors ynm itself reports (`ynm doctor`) | a store ynm can't read loses or hides memories |
| ynm distributed mount | without `ynm init` here, seats can't share what they learn |
| ynm syncs on push | Beads owns the git hooks, so `ynm init` can't add its pre-push sync; until it is appended, `git push` doesn't share memory |
| ynm registered with ynh | seats are ynh harnesses; without `ynm client install ynh` they get none of ynm's tools or hooks, on any vendor |
| Beads installed, work graph readable | all work lives in Beads |
| no Beads agent setup | `bd init` without `--skip-agents` writes skills, hooks and AGENTS.md blocks that tell agents to keep memory in `bd remember`, splitting it from ynm |
| seats wired (once the roster has seats) | each seat is started by its own name and wakes as itself: a harness of its own whose wake hook (the installed wake.sh, as the wake skill's "The hook command" gives it) names it, and no `BEADS_ACTOR` passed through for a stray shell variable to override |
| seats push at end (once the roster has seats) | each seat's session-end hook (`wake.sh --end`) pushes the memory and work it wrote; without it, they wait on this machine for the next `git push`, write or wake |
| seats wake by themselves (once the roster has seats) | each seat's `launch_focus` (ynh 0.15.0) names a focus it has, so started by its name it acts on its wake block instead of waiting bare |
| seats labelled (once the roster has seats) | the desk and every seat's harness carries `"labels": {"wheelhouse": "<name>"}`, the Wheelhouse's own name (the desk's), and no other Wheelhouse's. ynh stamps a harness's labels on every run record, so `ynr query runs --label wheelhouse:<name>` picks out this Wheelhouse's records when several share the laptop spool. A harness without it, or with another's, is a warning; needs ynh 0.17.0 or later, which an older ynh refuses |
| seats pick work-graph (once the roster has seats) | every harness's include of the wheelhouse plugin (path `plugins/wheelhouse`) delivers `skills/work-graph`, which carries `wheelhouse-lib.sh`, the library every wheelhouse script sources; without it a seat's scripts exit 3. An include with no pick, as the desk has, is the whole plugin and has it; another plugin included whole does not count. A pick that leaves it out is a warning, and a harness with no wheelhouse include is not checked |
| workspace folders (once the roster has seats) | every folder a seat's `workspace` asks for exists; ynh refuses one that doesn't. Granting them stays the human's |
| seat models (once the roster has seats) | each seat has a model: its own `model` tier, or its group's default in `models.groups`, mapping to a model for the claude vendor. A seat with none starts on whatever the launcher defaults to, which may be the dearest |
| general worker (once a worker has specialities) | a worker with no `specialities` takes what the specialists can't: their overflow, and beads none of them covers |
| seats born (once the roster has seats) | a seat with no pinned identity in its own namespace hasn't had its birth; the check names whose birth it is to run. With Beads memory it asks `memory.sh` for the seat's identity key |
| default human (once the roster exists) | the roster's `humans` holds exactly one human, with `"default": true`: the name for work that needs a human but no particular one. Any other human is per session and never in the roster. None is a warning (nothing to assign to, and no inbox at the desk); two or more is an error (the inbox script refuses to guess) |
| assignees known (once the roster exists) | every open bead is unassigned or assigned to a seat (in the roster, or on trial: `harnesses/<command>/AGENTS.md` on the checked-out branch, no roster entry yet), the default human, a human command with a `human/<command>` namespace in memory (ynm, or Beads' `human/<command>/` keys), or any human command on a bead labelled `inbox` (which `inbox.sh assign` puts on every bead it makes); one assigned to anyone else is in no seat's queue and no inbox |
| bare-session guard (once the desk has a manifest) | a vendor session opened in the repository without ynh is told, at start, that it is not a seat, so it doesn't act as the desk, claim beads or write seat memory. Each vendor the desk and seats run on needs `scripts/bare-guard.sh` and a session-start hook running it (Claude Code `.claude/settings.json`, Codex `.codex/hooks.json`, Cursor `.cursor/hooks.json`); a seat started through ynh is told nothing, as it carries the `wheelhouse:<name>` label. A warning when one is missing; the fix is `create-wheelhouse`'s `scripts/add-bare-guard-hook.sh`, whose diff the human reads before the commit. Copilot and OpenCode have no project-level hook the guard can use, and are named, not counted missing |
| pushed | work and memory reach other machines only when pushed; it warns about commits not yet pushed (as of the last fetch), and notes when there is no remote yet |
| work graph shared (once there is a remote) | `git push` doesn't carry the work graph: it shares through a Dolt remote on the repository's own origin, and pushes itself after each write once `dolt.auto-push` is on |
| memory syncs itself (once there is a remote) | ynm's `sync.auto` (ynm 0.5.0) syncs memory in the background after a turn; without it, what a seat remembers mid-session waits for a push, a wake or its session end, and a crash skips the end. An error when ynm is older than 0.5.0, which refuses a config with a `sync` block |

## Reporting

1. Lead with the verdict: set up right, or not. Report what the check found, and what you looked
   up just now; never what you remember from earlier in a session or another one. Which seats
   are born, what is pushed and what is in the work graph change between sessions, so check
   them rather than recall them.
2. List each failing check, most serious first, with its detail and its fix, as a command where
   there is one. Leave out the checks that passed, unless asked.
3. Note warnings briefly, after the errors.

## Fixing

**Ask before running any fix.** Each one changes something outside this conversation:
`ynm init` writes the repository's ynm config, `ynm client install ynh` changes ynh's setup,
`bd init` creates and commits files, `bd dolt push` publishes the work graph, and `brew install`
installs software. When the human says
yes, run the fixes one at a time, then run the check again and report what changed.

**Never repair, purge or rewrite a memory store yourself**, even when ynm reports it corrupt (or Beads' memory won't read). Say
what ynm reported and where, suggest the human looks at it with `ynm doctor`, and leave the store
alone. Memories that look broken may be the only copy.

If removing Beads' agent setup, take out only what Beads wrote: every `BEGIN BEADS ...` to
`END BEADS ...` block (Beads writes more than one, such as `INTEGRATION` and `CODEX SETUP`),
`.agents/skills/beads`, `.cursor/rules/beads.mdc` and the `bd` hook entries. Leave everything
else in those files as it is.

**`.claude/settings.json` is the human's to change.** Claude Code protects the settings it runs
under: an edit or delete from inside a session doesn't stick. Don't try. Tell the human the exact
entry to remove (the hook whose command is `bd prime --hook-json`), and run the check again after
they have. Never report it removed while the check still finds it.

After any fix, run the check again before you reply, even when part of the fix is left to the
human, and report what it still finds.
