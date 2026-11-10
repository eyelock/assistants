---
name: add-seat
description: Add a named seat to a Wheelhouse - a crew member, a standing role (such as a dispatcher) or a worker - as a ynh harness with its charter, standing orders and only the tools its job needs, named from the Wheelhouse's roster. Use when asked to add, create or set up a seat, role, worker or agent in a Wheelhouse (a release manager, a PR watcher, a dispatcher, a designer, more workers), or to give a role a name, or to start on a Wheelhouse's team (its starter team), one role at a time. Also use to trial, make official or drop a seat.
---

# Add a seat

A seat is a named role with a lasting identity: its claims and closes in Beads, its memories and
Kudos in ynm. Each seat is a ynh harness under `harnesses/<command>/` in the Wheelhouse
repository, started by its own name, and the desk (the repository's own harness) delegates to it.
Who seats a seat depends on who it works with. A seat is **crew** when the human works with it
directly (a designer, a reviewer, a tutor, a programme architect) and **standing** when it runs
on the desk's or a timer's say-so (a dispatcher, a CI watcher, a releaser); the human may still
speak to a standing seat, through the desk, about its output. The human
seats the crew they work with directly. The desk seats the standing roles. The human is there for
the births of both, since they speak to both. The dispatcher seats the workers, when the desk asks: it runs them, and knows who is idle. Seat only what your charter or
the human lets you; if asked for a seat that is someone else's to make, say whose it is.

A new seat is a **trial** until the human makes it official: see "Seating one seat at a time". The
one exception is a throwaway sandbox: see "The throwaway sandbox".

Work from the Wheelhouse repository root, the folder holding `.agents/harness/plugin.json`,
`.beads/` and `skills/roster/`.

## The starter team

Most Wheelhouses need the same first seats. Each is a template, one Markdown file per role, in
this skill's `assets/starter-team/`: `designer`, `reviewer`, `dispatcher`, `ci-watcher`,
`releaser`, `programme-manager` (optional), `verifier` (optional), `worker` and `specialist-worker` (optional). A file's
frontmatter gives its `order`, `group`, `focus`, `model` (its tier) and who seats it (`seated-by`); its body gives the
mandate, what the seat may and may not do, the focus prompt, and under `## Ask`, the questions to
ask before seating it. A role with more than one standing order lists its focuses
(`focus: [sweep, report]`), each with its prompt under `**Focus prompts:**`: the seat gets one
focus for each.

A Wheelhouse can change its team: a file of the same name in its own
`skills/roster/assets/starter-team/` replaces the template, and a new file adds a role. Read both
folders, the Wheelhouse's winning.

**Asked to set up the team,** don't seat the team: seating is one seat at a time (see "Seating one
seat at a time"). Offer one role, the first template in `order` (a Wheelhouse's file with no
`order` goes last) that isn't already seated, and wait:

1. Skip a role that is already seated: a seat in the roster with that `role`, or, for a seat with
   no `role`, one whose mandate is clearly the same job. A seat on trial (a branch with an open
   draft pull request) counts as seated.
2. Say in a line what the role is for, and ask one question: whether to seat it, under the first
   name in the group's pool that no seat holds and `excluded` doesn't list, in the pool's order
   ("Seat a designer, as Gahan?"). The human can change the name in the answer. A template with
   `optional: true` is offered, not assumed. Never seat a role the human hasn't agreed to. Then
   stop and wait for the answer: one question per message.
3. Once they agree, ask the template's `## Ask` questions, one per message, skipping any the
   request, the constitution or the roster already answers.
4. Don't change anything else while you seat it, such as the constitution or the scripts; mention
   what you'd fix, and leave it to the human.
5. Seat it from the template, through "Seating one seat at a time" and sections 2 to 4 below, and
   record `"role": "<template>"` on its roster seat. The workers are the dispatcher's to seat: if
   you are the desk, ask the dispatcher; if there is no dispatcher yet, say the workers come after
   one.
6. Then stop. Offer the next role only when the human asks for another seat, once this one is
   official or dropped (in a throwaway sandbox, once it is born: see "The throwaway sandbox").
   Never go on to it yourself.

**Asked for a particular seat** ("Seat Gore as our reviewer", "Add a worker for the api
repository"), seat what was asked, straight away, starting from the
role's template if there is one. The human asking is the human letting you. Ask first only for
what would change the charter and you can't tell; take everything else from the template, the
constitution and the roster, and raise anything else (such as where a repository is checked out)
in your report, after seating.

## Seating one seat at a time

Seating is intentional and led by the human: they ask for one seat, and it goes through these
steps before the next is started. Asked for several at once ("Add two workers"), seat the first
and say the next waits for the first to be made official or dropped (in a throwaway sandbox, for
its birth: see "The throwaway sandbox"). A new seat is a **trial** until the human makes it
official, so nothing about it is official when it is written.

1. **Write it on a branch.** The seating seat (the desk, or the dispatcher for a worker) works in
   its own git worktree, in its scratchpad, on a branch `seat/<command>` from
   `origin/<default branch>` (a shared checkout is often stale, and a seat never changes one).
   Do sections 1 to 4 below there, the roster entry and the desk's `delegates_to` excepted: they
   wait for the end of the trial (step 5). Commit it (`feat: seat <Name>`).
2. **Push it and open a draft pull request.** Open it as the constitution's `## Handing over work`
   says (a Wheelhouse with a tracker opens it with its `open-pr.sh`). Its description names the
   seat, its group and mandate, and says it is a trial: how to start it, and that the roster entry
   and the delegate come when the trial ends.
3. **Remove your own worktree,** once the branch is pushed, so the human can check the branch out.
4. **The trial, in the shared checkout.** The human checks the branch out there themselves, runs
   `ynh install ./harnesses/<command>` and starts the seat, so its paths are the real ones and
   nothing needs cleaning up later. Never check the branch out for them. Its install, its birth
   and its conversations are real: it has real memory and works real beads. Only the roster entry
   and the desk's `delegates_to` wait for the end of the trial, so the roster does not list it and
   the desk does not delegate to it yet. A charter change found in the trial goes onto the branch.
5. **Made official.** When the human ends the trial they switch the shared checkout back to the
   default branch. Then the seating seat adds the roster entry and the desk's `delegates_to` to
   the branch (in a new worktree of its own, removed again), so they arrive with the merge. The
   pull request leaves draft and is reviewed, and the human merges, pulls, and reinstalls the seat
   from the same path: `ynh install ./harnesses/<command>`. Then check the Wheelhouse with the
   `doctor` skill.
6. **Dropped.** The human switches back to the default branch and closes the pull request. Then
   the seat that winds down a dropped seat (below) does the rest:
   - uninstall it: `ynh uninstall local/<command>`;
   - hand every bead the dropped seat filed, claimed or was assigned to a named seat, the winding
     down seat by default (`bd update <id> --assignee <command> --actor <command>`, after reading
     each, since a claimed bead may be half-built);
   - add the dropped seat's name to the roster's `excluded` list, with the reason, so it is never
     reused;
   - leave its ynm namespace `seat/<command>` as it is: it is the record.

**Who winds a dropped seat down** is the seat the roster's `winds_down` names, the command of a
seat, such as `"winds_down": "<command>"`, beside `excluded`. Where it is not set, the desk does
it. Set it when the Wheelhouse has a seat for it (a coach, say); never assume one exists.

**A reviewer keeps a trial seat's pull request in draft,** whatever its verdict, until the human
ends the trial. A reviewer who finds it ready says so in its review, and leaves the pull request
in draft.

## The throwaway sandbox

One exception skips the trial: a throwaway sandbox, a Wheelhouse with no pull requests (a tutorial
or a trial run), and only when the human says so in the request ("this is a throwaway sandbox,
skip the trial"). The seat is written straight onto the working branch, with no `seat/<command>`
branch, worktree or pull request, and with its roster entry and the desk's `delegates_to` entry
at once. Everything else stands: seat one at a time, and for each one install it, trust it if ynh
asks, and wake it for its birth before the next. Never skip the trial on your own judgment, or
because a Wheelhouse has no pull requests yet: a real Wheelhouse's seats are trials.

## 1. Pin down the role

You need three things. Ask for any you can't tell from the request, one question at a time:

- **Group:** `crew` (the human works with it directly: it designs, reviews, teaches or plans with
  them), `standing` (one mandate, run on the desk's or a timer's say-so, not worked with directly) or `workers` (implements ready beads; see below). Choose by that one question: does
  the human work with this seat directly, or does it run on the desk's or a timer's say-so? If you can't tell, ask. It is the pool's key in the roster, and the
  seat's `group`.
- **Mandate:** one sentence, the job and nothing else, such as "Cuts releases when asked, and
  nothing else."
- **Reach:** the repositories and platforms the job touches, and whether it only reads them or
  also changes them. Where each repository is checked out is in the constitution's
  `## What it reaches`; if one isn't there, ask, and add it.

## Workers

Workers share a mandate, not a self. Each worker is a seat of its own, with its own name, harness
and command (`harnesses/okafor/`, started as `okafor`), so it is spoken to by name like any other
seat. Asked for several workers, seat one, and the next when it is official or dropped (in a throwaway sandbox, when it is born).

- Every worker gets the same mandate, standing order and charter, with only its name changed:
  build one bead at a time, first one assigned to you, else one nobody holds; work only on beads
  assigned to you or unassigned; hand finished work over for review as the constitution's
  `## Handing over work` says; never merge; hand review and design back to the crew.
- **Handing over** follows the constitution, written into the charter in its own words: either
  leave changes uncommitted in the working tree (never commit or push), or commit them on a
  branch and open a **draft** pull request. If the constitution says nothing, leave them
  uncommitted.
- Its standing order is `next`: take the next bead, build it and hand it over; a bead with a pull
  request stays in progress and closes when the pull request merges, one without closes with what
  actually happened.
- If the pool has fewer names than the human wants workers, seat the ones it has and ask for
  more names.
- **A specialist worker** has `specialities`: bead labels it takes work for, such as
  `"specialities": ["repo:ynh"]` for a worker for one repository, or `["lang:go"]`. Its charter
  says it takes only beads carrying one of those labels, and its harness can carry what the
  speciality needs, such as a language's skills. A worker with no `specialities` is general
  purpose and takes any bead.
- **Keep a general-purpose worker.** Specialists hand their overflow to one, and it takes beads
  no specialist covers. When you seat a specialist and the Wheelhouse has no
  general-purpose worker, say so and offer to seat one.

## Choosing the model

Every seat starts on a model, chosen by what it does: judgement, design and review get the
stronger model; watching, releasing and building get the cheaper one. The roster says so in a
vendor-agnostic way, so the Wheelhouse is not tied to one vendor's model names:

- A seat's `model` is a **tier**: `fast`, `balanced` or `deep`. A starter-team template carries
  its tier (workers, specialist workers, CI watchers and releasers `fast`; designers, reviewers,
  programme managers, verifiers and dispatchers `deep`); copy it to the roster seat, and ask only when you can't tell.
- A seat's optional `models` overrides the tier per vendor: `"models": {"claude": "haiku"}`.
- The roster's `models.tiers` says which model each tier is on each vendor, and `models.groups`
  gives each group a default tier for a seat with none, `desk` included. Without `tiers`, the
  plugin's own table applies (`fast` and `balanced` are `sonnet` and `deep` is `opus` on
  `claude`); add `models.tiers` to change it for a vendor.

```json
"models": {
  "groups": { "desk": "deep", "crew": "deep", "standing": "fast", "workers": "fast" },
  "tiers": { "deep": { "claude": "opus", "codex": "<model>" } }
}
```

`scripts/model.sh --seat <command> [--vendor <vendor>] [--format value|flag|json]` (in this
skill's folder, run from the Wheelhouse root or with `--dir`) resolves a seat's model, and
exits 4 when there is none. **Launch with it:** pass `$(model.sh --seat <command> --format flag)`
(`--model=sonnet`) when starting a seat from a launcher, and its `value` as the Agent tool's
`model` parameter when waking it as a subagent. ynh's `plugin.json` has no field for a launch
model, so the roster is where it is declared, and the launcher or the Agent call is where it is
applied. The `doctor` warns about a seat with no model.

## 2. Name it

Read `skills/roster/SKILL.md` and `skills/roster/assets/roster.json`, and follow the roster's
rules. In short:

- Take the name from the group's pool: the one the human asked for, or else the first unused one.
- Never reuse a name already in `seats`, even a retired seat's, and never use one in `excluded`.
  If the human asks for a taken or excluded name, say so and offer the next free one.
- The command is the name in lowercase ASCII, and `command -v <command>` must find nothing.
- If the pool is empty or used up, ask the human for more names. Don't invent any.

## 3. Write the harness

`harnesses/<command>/.agents/harness/plugin.json`:

```json
{
  "$schema": "https://eyelock.github.io/ynh/schema/plugin.schema.json",
  "name": "<command>",
  "version": "0.1.0",
  "description": "<Name>, <group> seat of the <wheelhouse> Wheelhouse: <mandate>",
  "default_vendor": "claude",
  "labels": { "wheelhouse": "<wheelhouse>" },
  "includes": [
    {
      "git": "https://github.com/eyelock/assistants",
      "path": "plugins/wheelhouse",
      "pick": ["skills/add-seat", "skills/birth", "skills/comms", "skills/create-wheelhouse", "skills/diataxis", "skills/doctor", "skills/handoff", "skills/kudos", "skills/patrol", "skills/vet-skill", "skills/wake", "skills/work-graph"]
    },
    { "git": "../..", "pick": ["skills/roster"] }
  ],
  "hooks": {
    "on_session_start": [{ "command": "bash scripts/wake.sh --seat <command> --format text || true" }],
    "on_session_end": [{ "command": "bash scripts/wake.sh --seat <command> --end || true", "timeout": 30 }]
  },
  "workspace": ["../../<a repository's path in What it reaches>"],
  "launch_focus": "wake",
  "focuses": {
    "wake": { "prompt": "Begin: act on your wake block. If there is none, gather it with the wake skill." },
    "<order>": { "prompt": "You are <Name>, the <command> seat. <the standing order>" }
  }
}
```

- `"git": "../.."` is the Wheelhouse repository itself, resolved from the seat's folder, and
  `pick` takes the roster skill from it. Use `pick`, not `"path": "skills/roster"`: a `path`
  names a folder that holds `skills/`, so pointing it at the skill itself includes nothing.
- A seat other than the desk picks the wheelhouse skills one by one: every skill in
  `plugins/wheelhouse/skills/` except `refresh`, as above (list the folder for the current set).
  `refresh` is the desk's alone: it reinstalls seats, so it belongs to the seat the human talks to,
  and the desk is the only harness that includes the whole plugin (no `pick`). A skill the plugin
  gains later reaches a seat only when its `pick` names it, so add it to the picks when the plugin
  gains one.
- `labels` is an object of key to value, and stamps every run record of the seat with
  `wheelhouse:<wheelhouse>`, the value being the Wheelhouse's own name (the desk harness's
  `name`). Every seat carries it, so `ynr query runs --label wheelhouse:<wheelhouse>` picks out
  this Wheelhouse's records when several share the laptop spool. It needs ynh 0.17.0 or later: an
  older ynh refuses the field, so a seat written with it won't start there. The value is always
  the desk's own name, never another Wheelhouse's or a person's.
- Add only what the mandate needs: other includes (such as `plugins/gitflow` for releases),
  MCP servers, and the environment variables they need in `env_passthrough`. Don't pass
  `BEADS_ACTOR` through: the seat names itself, so a variable left over in the human's shell
  can't make it act as someone else. A seat that only
  reads a platform gets its read-only server.
- One focus per standing order. Each prompt names the seat, and says what to do and when to stop.
- `launch_focus` makes the seat never wake bare: started by its name alone, it opens with the
  `wake` focus, so it acts on its wake block (its birth, or picking up from its notes) without
  waiting to be told. `<command> --focus <order>` still runs one standing order and stops, and a
  prompt given at launch replaces the wake prompt.
- `workspace` asks for the folders of the repositories the job changes or reads, and only those:
  a specialist gets its own repository, a general worker or a reviewer every one it works in, and
  a seat that only reads a platform (through `gh`, say) none. Paths are relative to the seat's
  folder, so a repository at `../ynh` from the Wheelhouse root is `../../../ynh`. A request grants
  nothing: the human grants it, with `ynh trust accept local/<command>` or their own `workspace_roots`
  in `~/.ynh/config.json`. Never run either for them.
- The `on_session_start` hook wakes the seat with purpose: it runs the Wheelhouse's
  `scripts/wake.sh` (copied there by `create-wheelhouse` from the `wake` skill), and the seat
  starts with who it is, where it left off, its Kudos and what is waiting for it. The hook names
  the seat (`--seat <command>`).
- The `on_session_end` hook pushes what the session wrote (`--end`: memory and the work graph),
  so nothing is left on this machine. Keep its `timeout`: without one, Claude Code gives it
  about 1.5 seconds. It is best effort; the next wake's sync catches anything it misses.

`harnesses/<command>/AGENTS.md` is the seat's charter:

```markdown
# <Name>

You are <Name>, the <command> seat: a <group> seat of the <wheelhouse> Wheelhouse.

**Mandate:** <mandate>

**You may:** <what the job lets it do>
**You may not:** <what it must leave to others or to the human>

**Name things fully.** In everything you write for people (chat, beads, notes, handoffs, pull
requests and issues):
- Name a web resource (a pull request, issue, CI run, review, commit or page) by its short form,
  always as a link: `[<repository> #12](https://github.com/<owner>/<repository>/pull/12)`, never a
  bare `#12` or a bare URL.
- Give a local path in full: `/Users/<you>/<checkout>/<wheelhouse>/AGENTS.md`, almost never a
  relative one, which hides which checkout or worktree you mean. Code and config keep their
  portable relative paths; this is about what you write for people.

**Never change a shared checkout.** Never switch branches, check out, detach, commit, reset or
stash in a repository checkout shared with the human and the other seats. Work in your own git
worktree in your scratchpad, branched from `origin/<default branch>` (shared checkouts are often
stale), with the worktree and its files named with your own command (subagent seats share the
desk's scratchpad). Read a branch with `git show` or `git diff`. Never use `git stash`: all
worktrees of a repository share one stash list. To set work aside, commit it to a throwaway
branch. A branch already checked out in another worktree: make a new local branch that tracks the
remote branch (`git worktree add -b <new branch> <path> --track origin/<remote branch>`) and push it
with `git -c push.default=upstream push`.

**Never name a human** in anything you post or write (pull requests, reviews, comments, beads,
notes, docs, commits): write the next action impersonally. In chat, call the human "you".
<For a seat that talks to the humans, the crew: Talk to the humans as the `comms` skill says:
decisions through the question tool, with options; a synopsis beside every bead id; the outcome
first.>

You act in the work graph as `<command>`: pass `--actor <command>` on every `bd` command that
changes it.
When something is outside your mandate, <where it goes>.
```

Fill the two examples in from the Wheelhouse's reach: one of its repositories on the web, and a
path in one of its checkouts. The constitution carries the same rule, word for word; the
charter repeats it because every seat writes for people.

Where it goes depends on who the seat works with: a crew seat raises it with the human it works
with; a standing role or a worker hands it back to the desk.

## 4. Connect it

1. Give the seat ynm: run `ynm client install ynh` inside `harnesses/<command>/`. It adds ynm's
   MCP server, hooks and memory skill to the seat's harness.
2. Add the seat to the desk's `delegates_to` in `.agents/harness/plugin.json`:
   `{ "git": ".", "path": "harnesses/<command>" }`. On a trial, leave it out until the human ends
   the trial.
3. Add the seat to `seats` in `skills/roster/assets/roster.json`: name, group, command, harness
   path and mandate; `model` (and `models`, for a per-vendor override); `seated-by`, the command of the seat seating it (or `human` when you aren't in
   a seat, or the human wrote every word); `role` when it was seated from a starter-team template;
   and `specialities` for a specialist worker. On a trial, the same applies: it waits for the
   end of the trial.
4. Check the Wheelhouse with the `doctor` skill.
5. Commit the seat on its branch (`feat: seat <Name>`) and go on to the draft pull request, as
   "Seating one seat at a time" says. The desk reads its delegates from the repository's commits,
   so it won't start until every seat in `delegates_to` is committed.

The seat's first session is its **birth** (the `birth` skill): it reads its charter, meets the
team and writes who it is, in its own words. Don't write its identity for it. A
seat's birth belongs to whoever works with it. The dispatcher wakes each worker it seats, once it
is installed (the human installs a trial seat, from the shared checkout): `ynh install ./harnesses/<command>`,
then
`<command> <flags> -- "This is your first session in <wheelhouse>. You were seated by <your command>."`,
as its own session. Nobody is there to approve what a birth does, so `<flags>` are the ones
you were given for starting seats (such as `--permission-mode`): without them its memory writes
are refused, and it can't save who it is. If you weren't given any, ask for them before you wake
anyone. Add the model from the roster (`--model=<model>`, from `model.sh`), never one copied
from another seat. Leave the birth
of a crew or standing seat to the human, who works with it directly and meets it themselves: install
it, but don't start it.

## 5. Report

Say who the seat is (name, group, mandate), what it can reach, its standing orders, and how to
start it, on trial: the human checks the branch out in the shared checkout, runs `ynh install ./harnesses/<command>`, then `<command>` to wake it, or
`<command> --focus <order>` for one standing order, written out for each seat when there are
several. Say it is a trial and where the draft pull request is, and that it becomes official on
review and merge, or is dropped. If it asks for workspace folders, say they are refused until the human grants them:
`ynh trust show local/<command>` lists them, and `ynh trust accept local/<command>` grants them, unless their
`workspace_roots` already covers them. If you left the seat uncommitted, say that the desk won't start
until it is committed. Say which seat is next only if asked.
