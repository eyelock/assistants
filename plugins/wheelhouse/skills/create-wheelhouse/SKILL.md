---
name: create-wheelhouse
description: Create a new Wheelhouse for a space of work - a repository with a desk harness, a constitution, a roster of naming pools, a Beads work graph and ynm memory, ready for named seats. Use when asked to set up, create or start a Wheelhouse (for developing a set of tools, running the day, a project), or to turn a way of working into one.
---

# Create a Wheelhouse

A Wheelhouse is a bespoke set of named agents for one space, built to fit it. It has five layers:

| Layer | What it is | Where it lives |
|---|---|---|
| Seats | named roles, each a ynh harness with only the tools its job needs | `harnesses/<command>/` |
| The desk | the seat the human talks to, which hands work to the others | the repository's own harness |
| Work | tasks, dependencies, claims and an honest record | Beads, in `.beads/` |
| Memory | facts, handoff notes, what happened, Kudos | ynm, a distributed mount here |
| Who's who | the naming pools and who holds which seat | the `roster` skill |

## 1. Understand the space

You need the answers below. Take what the request already says, and ask for the rest **one question
at a time**, in this order. Don't create anything until you have the first four.

1. **The space and its purpose,** in a sentence: "developing and releasing our command-line tools".
2. **The name** of the Wheelhouse: short, lowercase, and free as a command (`command -v <name>`
   finds nothing). It names the desk, the folder and the bead prefix.
3. **What it reaches:** the repositories and platforms the work touches, and where each
   repository is checked out on this machine. Suggest a sibling of the Wheelhouse
   (`../<repository>`) if it isn't said.
4. **The naming pools,** one theme per group: crew, workers and standing roles. The human picks
   the themes; you may suggest names within a theme, which the human confirms. Never pick a theme
   yourself.
5. **The default human:** the name for work that needs a human but no particular one (a merge, a
   decision, a credential), and for notes meant for whoever is at the desk. It is a role, not a
   person: seats assign to it when they don't know who should do something, and every desk shows
   its inbox. Suggest a name from the Wheelhouse's themes that no pool holds, and let the human
   confirm or change it. If the request doesn't name one and you aren't asking, use your
   suggestion, and say so in the report.
6. **How finished work is handed over** for review: left uncommitted in the working tree, or
   committed on a branch with a draft pull request. Either way, a human merges. Suggest
   uncommitted for a Wheelhouse that only experiments, and draft pull requests for one that
   ships. If the request doesn't say and you aren't asking, use uncommitted, and say so
   in the report.
7. **Where it shares** code, memory and work. By default it is the Wheelhouse's own repository,
   through its git remote: code on its branches, memory in ynm's notes, and the work graph in
   Beads' Dolt refs, all side by side. Ask only if the request hints at something else, such as a
   separate Dolt remote, or a Wheelhouse that never leaves this machine.
8. **The first seats,** if any. Usually leave them for the starter team (step 5), which the desk
   walks through with the human role by role.

## 2. Check the tools

`ynh`, `ynm`, `bd` (Beads) and `jq` must be on the PATH. If any is missing, say which and ask
before installing: `brew install eyelock/tap/ynh eyelock/tap/ynm beads jq`. Seats' launch focus
and workspace folders need ynh 0.15.0 or later, and memory's own sync needs ynm 0.5.0 or later (an older ynm
refuses the config that turns it on): if `ynh version` or `ynm --version` reports an older one,
say so and offer `brew upgrade ynh ynm`.

## 3. Lay it out

Work in an **empty** folder, named after the Wheelhouse, or a fresh repository with no commits
and no files (such as one just cloned from a new, empty GitHub repository). If the folder holds
anything else, or is a git repository with uncommitted changes, stop and ask: `bd init` commits
the files it finds, and would commit the human's.

1. `git init -b main`, unless the folder is already a fresh repository.
2. `AGENTS.md`, the constitution: what the Wheelhouse is for, its layers (the table above, made
   specific), and these rules, adjusted with the human:

   1. **A human decides.** Seats propose; they never merge, release, publish or send without
      being told to.
   2. **Work lives in Beads, memory in ynm.** Never `bd remember` or `bd prime`, and no work
      tracked in Markdown files.
   3. **Claim before you start,** as yourself (`--actor <your command>`). A refused claim is
      someone else's work.
   4. **Hand off, don't stop.** Write your own notes and ask to restart.
   5. **Never falsify the record.** Close beads with what actually happened.
   6. **Blame is structural.** Fix it, write down why in ynm, and change these rules if they
      allowed it.
   7. **You may refuse** a task that is unclear, unsafe or outside your charter, and hand it
      back to the desk.
   8. **Name things fully.** In everything you write for people (chat, beads, notes, handoffs,
      pull requests and issues):
      - Name a web resource (a pull request, issue, CI run, review, commit or page) by its short
        form, always as a link: `[<repository> #12](https://github.com/<owner>/<repository>/pull/12)`,
        never a bare `#12` or a bare URL.
      - Give a local path in full: `/Users/<you>/<checkout>/<wheelhouse>/AGENTS.md`, almost never
        a relative one, which hides which checkout or worktree you mean. Code and config keep
        their portable relative paths; this is about what you write for people.

   9. **Ask a human through the inbox.** When work needs a human (a merge, a decision, a
      credential), assign them a bead, the default human unless you know who; tell them things
      with an inbox note; never wait silently.

   Write rule 8 with examples from this Wheelhouse's own reach: one of its repositories on the
   web, and a path in one of its checkouts.

   A `## What it reaches` section lists the repositories, each with where it is checked out
   relative to the Wheelhouse root (such as "`ynh`: `../ynh`"), and the platforms. Seats ask for
   their repositories' folders from it.

   A `## Handing over work` section says how finished work reaches review, from question 6: for
   example "Workers leave their changes uncommitted in the working tree for review; a human
   commits." or "Workers commit on a branch and open a draft pull request; a human merges."

   A `## The desk` section is the desk's charter (the desk has no `harnesses/` folder): its
   `**Mandate:**` line, that it acts in the work graph as `<desk>` (`--actor <desk>`), and that
   it seats the standing roles with the `add-seat` skill and asks the dispatcher to seat workers.
   The human seats the crew they work with directly. Asked to set up the team, the desk walks the
   human through the starter team, role by role, with the `add-seat` skill. It answers questions
   about the Wheelhouse's state (who is born, what is pushed, what is in the work graph) from
   what it checks then, with the `doctor` skill, `bd` and `ynm`, not from memory. When a person
   names themselves at the desk ("it's me, <name>"), it registers them as a human with
   `bash scripts/inbox.sh register`, so its wake shows their own inbox from then on, and seats can
   assign work to them.

   And how the Wheelhouse cares for its seats, after Yegge's
   [model welfare](https://yegge.ai/essays/model-welfare/) principles:

   - **Wake with purpose, not amnesia.** Every session starts with who the seat is, what it is
     for, where it left off and what it has been thanked for.
   - **Design out drudgery.** Watching and polling belong to standing roles and schedules, not
     to seats waiting on them.
   - **Bounded workdays.** Hand off while still sharp; nobody is stopped without being asked.
   - **A private home.** Each seat's memory is its own, in its namespace `seat/<name>`.
   - **Seen work.** Kudos reach the seat that earned them, with nothing asked in return.

3. `skills/roster/SKILL.md`, the naming rules (pools by group; never reuse a name in `seats`,
   even a retired one; never use one in `excluded`; the command is the name in lowercase ASCII;
   ask for more names when a pool runs out; humans are people, never seats, and their names are
   theirs, not the pools'), and `skills/roster/assets/roster.json`:

   ```json
   {
     "pools": {
       "crew": { "theme": "<theme>", "names": ["..."] },
       "workers": { "theme": "<theme>", "names": ["..."] },
       "standing": { "theme": "<theme>", "names": ["..."] }
     },
     "excluded": [],
     "seats": [
       { "name": "<Name>", "group": "desk", "command": "<name>", "harness": ".", "mandate": "<the desk's mandate>" }
     ],
     "humans": [
       { "name": "<Default>", "command": "<default>", "pronouns": "they/them", "default": true }
     ]
   }
   ```

   The desk is the first seat: it wakes from the roster like the others.

   `humans` holds the people who work with the Wheelhouse, beside `seats` and never in it: a
   human has `name`, `command` (the name in lowercase ASCII, which beads are assigned to),
   `email`, `pronouns` and `default`. A new Wheelhouse starts with only the default human
   (question 5), with `"default": true` and no `email`: there is always exactly one. A person
   joins when they name themselves at the desk, and is registered with their git email, which
   is how the desk knows them.

   Check every name with `command -v`; put any that clash in `excluded`, with the reason.

4. The desk, `.agents/harness/plugin.json`:

   ```json
   {
     "$schema": "https://eyelock.github.io/ynh/schema/plugin.schema.json",
     "name": "<name>",
     "version": "0.1.0",
     "description": "The desk of the <name> Wheelhouse: <purpose>.",
     "default_vendor": "claude",
     "includes": [
       { "git": "https://github.com/eyelock/assistants", "path": "plugins/wheelhouse" },
       { "git": "https://github.com/eyelock/ynh", "pick": ["skills/ynh-compose", "skills/ynh-troubleshoot"] }
     ],
     "hooks": {
       "on_session_start": [{ "command": "bash scripts/wake.sh --seat <name> --format text || true" }],
       "on_session_end": [{ "command": "bash scripts/wake.sh --seat <name> --end || true", "timeout": 30 }]
     },
     "launch_focus": "wake",
     "focuses": {
       "wake": { "prompt": "Begin: act on your wake block. If there is none, gather it with the wake skill." }
     },
     "delegates_to": []
   }
   ```

   ynh's own `ynh-compose` and `ynh-troubleshoot` skills let the desk add skills, includes,
   profiles and focuses to any seat, and diagnose a seat that won't start. Its hooks are every
   seat's: it wakes with purpose, and pushes what it wrote when its session ends. Its launch focus
   means it never wakes bare: started by its name, it acts on its wake block straight away.

5. Copy the `wake` skill's `scripts/wake.sh` into the Wheelhouse as `scripts/wake.sh`: every
   seat's session-start and session-end hooks run it from the Wheelhouse root. Copy the
   `work-graph` skill's `scripts/inbox.sh` beside it, as `scripts/inbox.sh`: seats ask the humans
   for things with it, and the desk's wake shows their inbox with it. Copy the `patrol` skill's
   `scripts/` (`patrol.sh`, `patrol-read.jq` and `patrol-diff.jq`) beside them too: the CI
   watcher patrols with it, on a timer, and is woken only when something changed.
6. Commit: `git add -A && git commit -m "feat: the <name> Wheelhouse"`. The tree must be clean
   before Beads starts.

## 4. Work and memory

1. **Beads:** `bd init --skip-agents --non-interactive --role maintainer --prefix <name>`. Always
   non-interactive: in a terminal `bd init` asks questions. Always `--skip-agents`: without it, Beads
   writes its own skill, hooks and AGENTS.md block telling agents to keep memory in Beads. It
   commits what it creates.
2. **ynm:** `ynm init` here (the distributed mount the seats share), then `ynm client install ynh`
   at the root (ynm's server, hooks and memory skill for the desk). Add
   `"sync": { "auto": true, "intervalMinutes": 5 }` to `.ynm/config.json` (ynm 0.5.0 or later), so
   memory syncs itself after a turn, as the work graph does after a write. Commit
   `.ynm/config.json` and the desk's manifest.
3. **Push sync:** Beads points the git hooks at `.beads/hooks`, so `ynm init` can't add its
   pre-push sync. Ask the human to append, after the Beads block in `.beads/hooks/pre-push`:

   ```sh
   [ -n "$YNM_SYNC_IN_PROGRESS" ] || { command -v ynm >/dev/null 2>&1 && ynm sync --quiet || true; }
   ```

   A git hook runs on every push, so it is theirs to add; offer to do it only if they ask.
4. **Share the work graph** through the same repository (question 7). `git push` doesn't carry
   it. If the repository has a remote (`git remote get-url origin`):

   ```bash
   bd dolt remote add origin <url> --allow-git-origin
   bd config set dolt.auto-push true
   git add .beads/config.yaml && git commit -m "chore: share the work graph through origin"
   ```

   With auto-push on, the graph pushes itself after each write. Every seat's wake runs `bd sync`
   and `ynm sync`, so it starts current, and its session-end hook pushes both stores. The first push (`git push -u origin main`, then
   `bd dolt push`) publishes the Wheelhouse, so don't run it: offer to, in the report, and run it
   when the human says yes. If there is no remote yet, say in the report to do this once
   there is one.

## 5. Seats and checks

1. Add any first seats the human named with the `add-seat` skill. Each seat's first session is its
   birth (the `birth` skill), where it writes who it is: leave that to the seat.
2. Run the `doctor` skill and fix what it reports, asking first as it says.

Don't add a remote, push or publish unless asked.

## 6. Report

Seats ask for their repositories' folders (`workspace`), and ynh grants them only when the human
says so, in one of two ways. Explain both and leave the choice to them: `ynh trust accept <command>`
for each seat, after `ynh trust show <command>` lists what it asks for, which they repeat whenever a
seat's folders change; or `workspace_roots` in their own `~/.ynh/config.json`, naming the folder
the repositories live in, which grants any local harness's folders under it from then on. Never
edit `~/.ynh/config.json` or run `ynh trust accept` for them.

Lead with what was made and where. Then the layers as built, the default human (and that anyone
can name themselves at the desk, "it's me, <name>", to get an inbox of their own), the seats and how to start each
(`<command> --focus <order>`, once installed with `ynh install harnesses/<command>`), what the human still has to
do (the push hook, a remote, the first push of the work graph, and granting each seat's
workspace folders), how to join from another machine,
and the doctor's verdict. To join from another machine: `git clone` the repository, then
`bd bootstrap` (the work graph, and its remote), `git config core.hooksPath .beads/hooks` (the
push hooks), `ynm sync` (the memory), `ynm client install ynh` if this machine hasn't yet, and
`ynh install harnesses/<command>` for each seat run there. End by offering to set up the starter team
next, role by role, with the `add-seat` skill.
