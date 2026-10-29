---
name: doctor
description: Check a Wheelhouse is set up right - ynm installed and healthy, with a distributed mount in the Wheelhouse repository and registered with ynh, and Beads installed with a work graph and none of its own agent setup. Use when asked to check, validate or diagnose a Wheelhouse, its memory or its work graph, after creating one, or when a seat finds ynm or bd missing or misbehaving.
---

# Doctor

Run `scripts/check.sh` from this skill's folder, with `--dir` pointing at the Wheelhouse
repository (the one with the desk's `.agents/harness/` and `.beads/`). From the Wheelhouse root:

```bash
bash path/to/doctor/scripts/check.sh --dir .
```

It prints JSON: `ok`, and one entry per check with `name`, `ok`, `level`, `detail` and `fix`. It
changes nothing. `ok` is false when any check has level `error`.

## What it checks

| Check | Why it matters |
|---|---|
| ynm installed | seats keep their memory, handoff notes and Kudos in ynm |
| errors ynm itself reports (`ynm doctor`) | a store ynm can't read loses or hides memories |
| ynm distributed mount | without `ynm init` here, seats can't share what they learn |
| ynm syncs on push | Beads owns the git hooks, so `ynm init` can't add its pre-push sync; until it is appended, `git push` doesn't share memory |
| ynm registered with ynh | seats are ynh harnesses; without `ynm client install ynh` they get none of ynm's tools or hooks, on any vendor |
| Beads installed, work graph readable | all work lives in Beads |
| no Beads agent setup | `bd init` without `--skip-agents` writes skills, hooks and AGENTS.md blocks that tell agents to keep memory in `bd remember`, splitting it from ynm |
| seats wired (once the roster has seats) | each seat is started by its own name and wakes as itself: a harness of its own whose wake hook names it, and no `BEADS_ACTOR` passed through for a stray shell variable to override |

## Reporting

1. Lead with the verdict: set up right, or not.
2. List each failing check, most serious first, with its detail and its fix, as a command where
   there is one. Leave out the checks that passed, unless asked.
3. Note warnings briefly, after the errors.

## Fixing

**Ask before running any fix.** Each one changes something outside this conversation:
`ynm init` writes the repository's ynm config, `ynm client install ynh` changes ynh's setup,
`bd init` creates and commits files, and `brew install` installs software. When the human says
yes, run the fixes one at a time, then run the check again and report what changed.

**Never repair, purge or rewrite a memory store yourself**, even when ynm reports it corrupt. Say
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
