---
name: create-wheelhouse
description: Create a new Wheelhouse for a space of work - a repository with a desk harness, a constitution, a roster of naming pools, a Beads work graph and memory in ynm or Beads, ready for named seats. Use when asked to set up, create or start a Wheelhouse (for developing a set of tools, running the day, a project), or to turn a way of working into one.
---

# Create a Wheelhouse

A Wheelhouse is a bespoke set of named agents for one space, built to fit it. It has five layers:

| Layer | What it is | Where it lives |
|---|---|---|
| Seats | named roles, each a ynh harness with only the tools its job needs | `harnesses/<command>/` |
| The desk | the seat the human talks to, which hands work to the others | the repository's own harness |
| Work | tasks, dependencies, claims and an honest record | Beads, in `.beads/` |
| Memory | facts, handoff notes, what happened, Kudos | ynm, a distributed mount here, or Beads, as `wheelhouse.json` says |
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
4. **The naming pools,** one theme per group: crew (seats the human works with directly, such as
   a designer, a reviewer, a tutor or a programme architect), workers, and standing roles (seats
   that run on the desk's or a timer's say-so, such as a dispatcher, a CI watcher or a releaser). The human picks
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
   through its git remote: code on its branches, memory in ynm's notes (or, with Beads memory, in the
   same Dolt refs as the work graph), and the work graph in Beads' Dolt refs, all side by side. Ask only if the request hints at something else, such as a
   separate Dolt remote, or a Wheelhouse that never leaves this machine.
8. **The tracker:** where the humans see the project, apart from the work graph: GitHub Issues,
   JIRA, another, or none. For one, gather what `tracker.json` needs (the `work-graph` skill's
   `references/tracker.md` has the shape): the kind; what it calls an item and a release
   (issue/milestone, ticket/fixVersion); how an item is referenced, with a safe pattern for it; and
   the CLI the humans want used to change an item's release; and whether any repository is exempt
   from the tracker (`exempt_repos`), such as the Wheelhouse's own repository when it plans in
   beads: ask, and leave it out when none is. The config holds no commands. GitHub
   has an adapter, `tracker-github.sh`, so nothing more is needed. **Any other tracker needs an
   adapter script** (`tracker-<kind>.sh` in the `work-graph` skill, with `release`, `state`,
   `canon`, `closing` and `pr-flags` written as plain code): until it exists, pull requests can't
   be opened through `open-pr.sh` for that tracker. Say so, and offer to write the adapter as a
   bead. If the request doesn't say and you aren't asking, use none, and say so in the report.
9. **The first seats,** if any. Usually leave them for the starter team (step 5), which the desk
   offers the human one role at a time. When the human names a role of their own, put it in a
   group by asking whether they will work with that seat directly (crew) or whether it runs on the
   desk's or a timer's say-so (standing).
10. **Agent Tasks:** where the seats' work lives. Beads is the only option; ask so the choice is
    explicit and recorded, and take "Beads" as the answer when the request says nothing.
11. **Agent Memory:** where the seats' identity, handoff notes, Kudos and close notes live: **ynm**
    (the default) or **Beads** (`bd remember`, in the same database as the work graph, shared by
    the same Dolt remote). Say what Beads gives up: no private home (everyone who syncs the graph
    sees every memory), no search by meaning, no ynm tools or `ynm-memory` skill (seats use
    `scripts/memory.sh`), and no forget reason or history of superseded memories. If the request
    doesn't say and you aren't asking, use ynm, and say so in the report.

Ask questions 10 and 11 one at a time like the rest. Both go into `wheelhouse.json` (step 3.6).

## 2. Check the tools

`ynh`, `bd` (Beads) and `jq` must be on the PATH, and `ynm` too when memory is in ynm (a Beads
Wheelhouse needs no ynm). If any is missing, say which and ask before installing:
`brew install eyelock/tap/ynh eyelock/tap/ynm beads jq` (leave out `eyelock/tap/ynm` for Beads
memory). Seats' launch focus and workspace folders need ynh 0.15.0 or later, and ynm's own sync
needs ynm 0.5.0 or later (an older ynm refuses the config that turns it on): if `ynh version` or
`ynm --version` reports an older one, say so and offer `brew upgrade ynh ynm`.

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
   2. **Work lives in Beads, memory in <ynm or Beads, as chosen in question 11>.** Write it as
      one of these two, whichever the human chose:
      - ynm: "**Work lives in Beads, memory in ynm.** Never `bd remember` or `bd prime`, and no
        work tracked in Markdown files."
      - Beads: "**Work and memory live in Beads.** Read and write memory only through
        `scripts/memory.sh`, never `bd remember` or `ynm` by hand, never `bd prime`, and no work
        tracked in Markdown files."
   3. **Claim before you start,** as yourself (`--actor <your command>`). A refused claim is
      someone else's work.
   4. **Hand off, don't stop.** Write your own notes and ask to restart. A seat woken as a
      subagent has no session of its own to restart: it ends by returning its report, and the seat
      that woke it waits for it before handing off or exiting.
   5. **Never falsify the record.** Close beads with what actually happened. The one forced
      close a seat may make of a bead it does not hold: the desk closes a human's inbox bead,
      only through `inbox.sh close`, once the work is verified done.
   6. **Blame is structural.** Fix it, write down why in memory (`scripts/memory.sh`), and change these rules if they
      allowed it.
   7. **You may refuse** a task that is unclear, unsafe or outside your charter, and hand it
      back to the desk.
   8. **Never change a shared checkout.** A repository's checkout under "What it reaches" is
      shared with the human and the other seats. Never switch branches, check out, detach,
      commit, reset or stash there. To work on or test a branch, use your own git worktree in
      your scratchpad, branched from `origin/<the branch your pull request targets>` (a shared checkout is
      often stale), and name the worktree and any file you keep there with your own command, because
      subagent seats share the desk's scratchpad. To read a branch, use `git show` or `git diff`.
      Never use `git stash`, even in your own worktree: every worktree of a repository shares one
      stash list, so a stash lands in the shared checkout too. To set work aside, commit it to a
      throwaway branch. If the branch you need is already checked out in another worktree, make a
      new local branch that tracks the remote branch (`git worktree add -b <new branch> <path> --track
      origin/<remote branch>`) and push it with `git -c push.default=upstream push`.
   9. **Name things fully.** In everything you write for people (chat, beads, notes, handoffs,
      pull requests and issues):
      - Name a web resource (a pull request, issue, CI run, review, commit or page) by its short
        form, always as a link: `[<repository> #12](https://github.com/<owner>/<repository>/pull/12)`,
        never a bare `#12` or a bare URL.
      - Give a local path in full: `/Users/<you>/<checkout>/<wheelhouse>/AGENTS.md`, almost never
        a relative one, which hides which checkout or worktree you mean. Code and config keep
        their portable relative paths; this is about what you write for people.

   10. **Ask a human through the inbox.** When work needs a human (a merge, a decision, a
      credential), assign them a bead, the default human unless you know who; tell them things
      with an inbox note; never wait silently.
   11. **Never name a human** in anything you post or write (pull requests, reviews, comments,
       beads, notes, docs, commits): write the next action impersonally ("Decision needed before
       merge: A or B", "Next action: a maintainer merges it"). In chat, call the human "you".
       Seats that talk to the humans follow the `comms` skill: decisions asked through the
       question tool, with options; a synopsis beside every bead id; the outcome first.

   Write rule 9 with examples from this Wheelhouse's own reach: one of its repositories on the
   web, and a path in one of its checkouts.

   A `## What it reaches` section lists the repositories, each with where it is checked out
   relative to the Wheelhouse root (such as "`ynh`: `../ynh`"), and the platforms. Seats ask for
   their repositories' folders from it.

   A `## Handing over work` section says how finished work reaches review, from question 6: for
   example "Workers leave their changes uncommitted in the working tree for review; a human
   commits." or "Workers commit on a branch and open a draft pull request; a human merges."
   When the Wheelhouse has a tracker (question 8), add: "A build bead's `external_ref` holds the
   full URL or key of its tracker item; only beads labelled `housekeeping`, or in a repository the tracker config's
   `exempt_repos` names, go without. The
   release is read from the item, never copied onto the bead. Workers open pull requests only
   with the `work-graph` skill's `scripts/open-pr.sh`." Also add, where a programme manager is or
   will be seated: "An audit, spike or finished design that finds a gap in what a tool does hands
   it to the programme manager, not straight into the work graph: the designer or auditor writes
   it on the bead and hands it to the desk, which wakes the programme manager; the programme
   manager places it in the roadmap and files its tracker item, and only then are build beads cut,
   against that item. Review fixes and CI failures stay beads, filed by the reviewer and the CI
   watcher."

   A `## The desk` section is the desk's charter (the desk has no `harnesses/` folder): its
   `**Mandate:**` line, that it acts in the work graph as `<desk>` (`--actor <desk>`), and that
   it seats the standing roles with the `add-seat` skill and asks the dispatcher to seat workers.
   The human seats the crew they work with directly. Asked to set up the team, the desk offers the
   starter team's first missing role with the `add-seat` skill, one seat at a time, each a trial
   until the human makes it official (a throwaway sandbox the human names as one skips the trial,
   as `add-seat` says). When a releaser is
   seated, the desk routes every release bead and every "can we release?" to the releaser, and
   never to a worker. When a programme manager is seated, the desk hands it a finished design: when
   the designer hands one over, wake the programme manager for it, and build beads are cut only
   once it has filed its tracker item. It answers questions
   about the Wheelhouse's state (who is born, what is pushed, what is in the work graph) from
   what it checks then, with the `doctor` skill, `bd` and the memory (`scripts/memory.sh`), not from recall. It talks to
   the humans as the `comms` skill says, asking what waits on them through the question tool
   with options, never as a list in prose. Who is at the desk is
   per session: with no name, its wake shows the default human's inbox; when a person names
   themselves ("it's me, <name>"), it runs `bash scripts/inbox.sh show --name <Name>`, so it shows
   their own inbox for that session, and seats can assign work to them by their lowercase name.
   Nothing about them is saved: no roster entry, no email, no username. It never checks GitHub
   itself to keep the inbox and the work graph current, and never loops over `gh`: when a CI
   watcher is seated, on a merge signal (the human says they merged, or a seat reports a pull
   request ready or merged) it signals the CI watcher to reap, then passes the merged pull
   requests, reported as bead then pull request, to the dispatcher, who closes the work beads, and
   closes each reported inbox item with `inbox.sh close`, with a reason saying what happened.
   It starts every seat on the model the roster gives it: the Agent tool's
   `model` parameter when it wakes a seat as a subagent, `--model` when it starts a launcher,
   both from the `add-seat` skill's `scripts/model.sh --seat <command>`.

   And how the Wheelhouse cares for its seats, after Yegge's
   [model welfare](https://yegge.ai/essays/model-welfare/) principles:

   - **Wake with purpose, not amnesia.** Every session starts with who the seat is, what it is
     for, where it left off and what it has been thanked for.
   - **Design out drudgery.** Watching and polling belong to standing roles and schedules, not
     to seats waiting on them.
   - **Bounded workdays.** Hand off while still sharp; nobody is stopped without being asked.
   - **A private home.** With ynm memory: each seat's memory is its own, in its namespace
     `seat/<name>`. With Beads memory, which has no private home, write: "**A home of its own.**
     Each seat's memory is its own to write, under its keys `seat/<name>/`; everyone who syncs the
     work graph can read it."
   - **Seen work.** Kudos reach the seat that earned them, with nothing asked in return.

3. `skills/roster/SKILL.md`, the naming rules (pools by group: crew are the seats the human works
   with directly, standing roles run on the desk's or a timer's say-so; never reuse a name in `seats`,
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
     "models": {
       "groups": { "desk": "deep", "crew": "deep", "standing": "fast", "workers": "fast" }
     },
     "seats": [
       { "name": "<Name>", "group": "desk", "command": "<name>", "harness": ".", "mandate": "<the desk's mandate>" }
     ],
     "humans": [
       { "name": "<Default>", "command": "<default>", "pronouns": "they/them", "default": true }
     ]
   }
   ```

   The desk is the first seat: it wakes from the roster like the others.

   `models` says which model each seat starts on, by tier (`fast`, `balanced`, `deep`), and the
   `add-seat` skill explains it: a seat's `model` overrides its group's default, `models.tiers`
   maps tiers to models per vendor, and the desk wakes its subagents with the Agent tool's
   `model` parameter and starts launchers with `--model`, both from `scripts/model.sh`.

   `humans` holds only the default human, beside `seats` and never in it: `name`, `command` (the
   name in lowercase ASCII, which beads are assigned to), `pronouns` and `"default": true`
   (question 5). There is always exactly one. No other human is written to the roster, and no
   email or username is stored anywhere: a person is at the desk for a session by naming
   themselves, and their command is their name in lowercase. Every open bead is unassigned or assigned to
   a seat, the default human, a human command with a `human/<command>` namespace in ynm (with Beads memory, `human/<command>/` keys), or any human command on a bead labelled `inbox` (which `inbox.sh assign` puts on every bead it makes).

   Check every name with `command -v`; put any that clash in `excluded`, with the reason.

4. The desk, `.agents/harness/plugin.json`:

   ```json
   {
     "$schema": "https://eyelock.github.io/ynh/schema/plugin.schema.json",
     "name": "<name>",
     "version": "0.1.0",
     "description": "The desk of the <name> Wheelhouse: <purpose>.",
     "default_vendor": "claude",
     "labels": { "wheelhouse": "<name>" },
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

   `labels` is an object of key to value, and stamps every run record of the desk with
   `wheelhouse:<name>`, the value being the Wheelhouse's own name, and `add-seat` writes the same
   label into every seat's harness. When several Wheelhouses share the laptop spool,
   `ynr query runs --label wheelhouse:<name>` picks out this one's records. It needs ynh 0.17.0 or
   later: an older ynh refuses the field, so a desk written with it won't start there.

   ynh's own `ynh-compose` and `ynh-troubleshoot` skills let the desk add skills, includes,
   profiles and focuses to any seat, and diagnose a seat that won't start. Its hooks are every
   seat's: it wakes with purpose, and pushes what it wrote when its session ends. Its launch focus
   means it never wakes bare: started by its name, it acts on its wake block straight away.

   The desk includes the whole `plugins/wheelhouse` plugin, with no `pick`, so it gains every skill
   the plugin gains, `refresh` among them. Every other seat picks the wheelhouse skills and leaves
   `refresh` out (the `add-seat` skill says how).

5. Copy the `wake` skill's `scripts/wake.sh` into the Wheelhouse as `scripts/wake.sh`: every
   seat's session-start and session-end hooks run it from the Wheelhouse root. Copy the
   `work-graph` skill's `scripts/inbox.sh` beside it, as `scripts/inbox.sh`: seats ask the humans
   for things with it, and the desk's wake shows their inbox with it. Copy the `work-graph` skill's
   `scripts/memory.sh` beside them too, for either choice: the wake, the inbox and the skills read
   and write each seat's memory only with it, over ynm or Beads as `wheelhouse.json` says. Copy the `patrol` skill's
   `scripts/` (`patrol.sh`, `patrol-read.jq` and `patrol-diff.jq`) beside them too: the CI
   watcher patrols with it, on a timer, and is woken only when something changed.
6. `wheelhouse.json` at the Wheelhouse root, beside `tracker.json`, from questions 10 and 11:
   `{ "tasks": "beads", "memory": "ynm" }` or `{ "tasks": "beads", "memory": "beads" }`. Nothing in
   it is run. Without the file, or without the `memory` key, the scripts assume ynm.
7. `tracker.json`, the tracker config (question 8), in the shape of the `work-graph` skill's
   `references/tracker.md`. Write `{ "kind": "none" }` for no tracker. The constitution's
   "Handing over work" section says that a build bead's `external_ref` holds its tracker item.
8. Commit: `git add -A && git commit -m "feat: the <name> Wheelhouse"`. The tree must be clean
   before Beads starts.

## 4. Work and memory

Memory follows the choice in question 11. With Beads memory, do steps 1 and 4 only: memory is in the
same database as the work graph, so there is no `ynm init`, no `ynm client install ynh`, no ynm
config and no ynm push sync.

1. **Beads:** `bd init --skip-agents --non-interactive --role maintainer --prefix <name>`. Always
   non-interactive: in a terminal `bd init` asks questions. Always `--skip-agents`: without it, Beads
   writes its own skill, hooks and AGENTS.md block telling agents to keep memory in Beads. It
   commits what it creates.
2. **ynm** (ynm memory only)**:** `ynm init` here (the distributed mount the seats share), then `ynm client install ynh`
   at the root (ynm's server, hooks and memory skill for the desk). Add
   `"sync": { "auto": true, "intervalMinutes": 5 }` to `.ynm/config.json` (ynm 0.5.0 or later), so
   memory syncs itself after a turn, as the work graph does after a write. Commit
   `.ynm/config.json` and the desk's manifest.
3. **Push sync** (ynm memory only)**:** Beads points the git hooks at `.beads/hooks`, so `ynm init` can't add its
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
   (and `ynm sync` with ynm memory), so it starts current, and its session-end hook pushes the
   stores. With Beads memory that is one store, so the one `bd sync` and push carry both. The first push (`git push -u origin main`, then
   `bd dolt push`) publishes the Wheelhouse, so don't run it: offer to, in the report, and run it
   when the human says yes. If there is no remote yet, say in the report to do this once
   there is one.

## 5. Seats and checks

1. Add any first seats the human named with the `add-seat` skill. Each seat's first session is its
   birth (the `birth` skill), where it writes who it is: leave that to the seat.
2. Run the `doctor` skill and fix what it reports, asking first as it says.
3. Tell the human the desk applies merged changes with the `refresh` skill after they pull: it
   reinstalls the seats the diff touches, prints each `ynh trust accept local/<seat>` for them to run (it asks ynh which seats are no longer trusted), and
   lists the seats to restart. It is the desk's alone; no other seat is told to run it.

Don't add a remote, push or publish unless asked.

## 6. Report

Seats ask for their repositories' folders (`workspace`), and ynh grants them only when the human
says so, in one of two ways. Explain both and leave the choice to them: `ynh trust accept local/<command>`
for each seat, after `ynh trust show local/<command>` lists what it asks for, which they repeat whenever
anything the digest covers changes (a seat's folders, sensors, hooks, MCP servers in any profile, launch
focus or delegate focuses); or `workspace_roots` in their own `~/.ynh/config.json`, naming the folder
the repositories live in, which grants any local harness's folders under it from then on. Never
edit `~/.ynh/config.json` or run `ynh trust accept` for them.

Lead with what was made and where. Then the layers as built, the default human (and that anyone
can name themselves at the desk, "it's me, <name>", to get an inbox of their own), the seats and how to start each
(`<command> --focus <order>`, once installed with `ynh install ./harnesses/<command>`), what the human still has to
do (with ynm memory, the push hook; a remote, the first push of the work graph, and granting each seat's
workspace folders), how to join from another machine,
and the doctor's verdict, saying whether any fix was needed to reach it (none, when the layout passed as written). To join from another machine: `git clone` the repository, then
`bd bootstrap` (the work graph, and its remote, which carries Beads memory too), `git config
core.hooksPath .beads/hooks` (the push hooks), and, with ynm memory, `ynm sync` (the memory) and
`ynm client install ynh` if this machine hasn't yet, and
`ynh install ./harnesses/<command>` for each seat run there. End by offering the first role of the starter
team, one seat at a time, with the `add-seat` skill.
