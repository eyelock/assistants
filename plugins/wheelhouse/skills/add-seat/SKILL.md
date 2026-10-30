---
name: add-seat
description: Add a named seat to a Wheelhouse - a crew member, a standing role (such as a dispatcher) or a worker - as a ynh harness with its charter, standing orders and only the tools its job needs, named from the Wheelhouse's roster. Use when asked to add, create or set up a seat, role, worker or agent in a Wheelhouse (a release manager, a PR watcher, a dispatcher, a designer, more workers), or to give a role a name, or to set up a Wheelhouse's team (its starter team) role by role.
---

# Add a seat

A seat is a named role with a lasting identity: its claims and closes in Beads, its memories and
Kudos in ynm. Each seat is a ynh harness under `harnesses/<command>/` in the Wheelhouse
repository, started by its own name, and the desk (the repository's own harness) delegates to it.
Who seats a seat depends on who works with it. The human seats the crew they work with directly.
The desk seats the standing roles. The human is there for the births of both, since they talk to
both. The dispatcher seats the workers, when the desk asks: it runs them, and knows who is idle. Seat only what your charter or
the human lets you; if asked for a seat that is someone else's to make, say whose it is.

Work from the Wheelhouse repository root, the folder holding `.agents/harness/plugin.json`,
`.beads/` and `skills/roster/`.

## The starter team

Most Wheelhouses need the same first seats. Each is a template, one Markdown file per role, in
this skill's `assets/starter-team/`: `designer`, `reviewer`, `dispatcher`, `ci-watcher`,
`releaser`, `worker` and `specialist-worker`. A file's frontmatter gives its `order`, `group`,
`focus` and who seats it (`seated-by`); its body gives the mandate, what the seat may and may not
do, the focus prompt, and under `## Ask`, the questions to ask before seating it.

A Wheelhouse can change its team: a file of the same name in its own
`skills/roster/assets/starter-team/` replaces the template, and a new file adds a role. Read both
folders, the Wheelhouse's winning.

**Asked to set up the team,** walk the templates in `order` (a Wheelhouse's file with no `order`
goes last), one role at a time:

1. Skip a role that is already seated: a seat in the roster with that `role`, or, for a seat with
   no `role`, one whose mandate is clearly the same job.
2. Say in a line what the role is for, and ask one question: whether to seat it, under the first
   name in the group's pool that no seat holds and `excluded` doesn't list, in the pool's order
   ("Seat a designer, as Gahan?"). The human can change the name in the answer. A template with
   `optional: true` is offered, not assumed. Never seat a role the human hasn't agreed to. Then
   stop and wait for the answer: one question per message.
3. Once they agree, ask the template's `## Ask` questions, one per message, skipping any the
   request, the constitution or the roster already answers.
4. Don't change anything else while you walk, such as the constitution or the scripts; mention
   what you'd fix, and leave it to the human.
5. Seat it from the template, through sections 2 to 4 below, and record `"role": "<template>"` on
   its roster seat. In the walk, the workers are the dispatcher's to seat: if you are the desk,
   ask the dispatcher; if there is no dispatcher yet, say the workers come after one.
6. Then go on to the next role.

**Asked for a particular seat** ("Seat Gore as our reviewer", "Add two workers", "Add a worker for
the api repository"), don't walk the team: seat what was asked, straight away, starting from the
role's template if there is one. The human asking is the human letting you. Ask first only for
what would change the charter and you can't tell; take everything else from the template, the
constitution and the roster, and raise anything else (such as where a repository is checked out)
in your report, after seating.

## 1. Pin down the role

You need three things. Ask for any you can't tell from the request, one question at a time:

- **Group:** `crew` (designs work and reviews it), `standing` (one mandate, runs unattended) or
  `workers` (implements ready beads; see below). It is the pool's key in the roster, and the
  seat's `group`.
- **Mandate:** one sentence, the job and nothing else, such as "Cuts releases when asked, and
  nothing else."
- **Reach:** the repositories and platforms the job touches, and whether it only reads them or
  also changes them.

## Workers

Workers share a mandate, not a self. Each worker is a seat of its own, with its own name, harness
and command (`harnesses/okafor/`, started as `okafor`), so it is spoken to by name like any other
seat. Asked for several workers, seat each one in turn, through steps 2 to 4 and its birth.

- Every worker gets the same mandate, standing order and charter, with only its name changed:
  build one bead at a time, first one assigned to you, else one nobody holds; work only on beads
  assigned to you or unassigned; hand finished work over for review as the constitution's
  `## Handing over work` says; never merge; hand review and design back to the crew.
- **Handing over** follows the constitution, written into the charter in its own words: either
  leave changes uncommitted in the working tree (never commit or push), or commit them on a
  branch and open a **draft** pull request. If the constitution says nothing, leave them
  uncommitted.
- Its standing order is `next`: take the next bead, build it, and close it with what actually
  happened.
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
  "includes": [
    { "git": "https://github.com/eyelock/assistants", "path": "plugins/wheelhouse" },
    { "git": "../..", "pick": ["skills/roster"] }
  ],
  "hooks": {
    "on_session_start": [{ "command": "bash scripts/wake.sh --seat <command> --format text || true" }],
    "on_session_end": [{ "command": "bash scripts/wake.sh --seat <command> --end || true", "timeout": 30 }]
  },
  "focuses": {
    "<order>": { "prompt": "You are <Name>, the <command> seat. <the standing order>" }
  }
}
```

- `"git": "../.."` is the Wheelhouse repository itself, resolved from the seat's folder, and
  `pick` takes the roster skill from it. Use `pick`, not `"path": "skills/roster"`: a `path`
  names a folder that holds `skills/`, so pointing it at the skill itself includes nothing.
- Add only what the mandate needs: other includes (such as `plugins/gitflow` for releases),
  MCP servers, and the environment variables they need in `env_passthrough`. Don't pass
  `BEADS_ACTOR` through: the seat names itself, so a variable left over in the human's shell
  can't make it act as someone else. A seat that only
  reads a platform gets its read-only server.
- One focus per standing order. Each prompt names the seat, and says what to do and when to stop.
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

You act in the work graph as `<command>`: pass `--actor <command>` on every `bd` command that
changes it.
When something is outside your mandate, <where it goes>.
```

Where it goes depends on who the seat works with: a crew seat raises it with the human it works
with; a standing role or a worker hands it back to the desk.

## 4. Connect it

1. Give the seat ynm: run `ynm client install ynh` inside `harnesses/<command>/`. It adds ynm's
   MCP server, hooks and memory skill to the seat's harness.
2. Add the seat to the desk's `delegates_to` in `.agents/harness/plugin.json`:
   `{ "git": ".", "path": "harnesses/<command>" }`.
3. Add the seat to `seats` in `skills/roster/assets/roster.json`: name, group, command, harness
   path and mandate; `seated-by`, the command of the seat seating it (or `human` when you aren't in
   a seat, or the human wrote every word); `role` when it was seated from a starter-team template;
   and `specialities` for a specialist worker.
4. Check the Wheelhouse with the `doctor` skill.
5. Commit the seat (`feat: seat <Name>`), unless the human said not to. The desk reads its
   delegates from the repository's commits, so it won't start until every seat in
   `delegates_to` is committed.

The seat's first session is its **birth** (the `birth` skill): it reads its charter, meets the
team and writes who it is, in its own words. Don't write its identity for it. A
seat's birth belongs to whoever works with it. The dispatcher wakes each worker it seats, once it
is installed: `ynh install harnesses/<command>`, then
`<command> <flags> -- "This is your first session in <wheelhouse>. You were seated by <your command>."`,
as its own session. Nobody is there to approve what a birth does, so `<flags>` are the ones
you were given for starting seats (such as `--model` and `--permission-mode`): without them its
memory writes are refused, and it can't save who it is. If you weren't given any, ask for them
before you wake anyone. Leave the birth
of a crew or standing seat to the human, who works with it directly and meets it themselves: install
it, but don't start it.

## 5. Report

Say who the seat is (name, group, mandate), what it can reach, its standing orders, and how to
start it: `ynh install harnesses/<command>`, then `<command> --focus <order>`, written out for each
seat when there are several. If you left the seat uncommitted, say that the desk won't start
until it is committed.
