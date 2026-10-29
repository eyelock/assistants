---
name: add-seat
description: Add a named seat to a Wheelhouse - a crew member, a standing role (such as a dispatcher) or a worker - as a ynh harness with its charter, standing orders and only the tools its job needs, named from the Wheelhouse's roster. Use when asked to add, create or set up a seat, role, worker or agent in a Wheelhouse (a release manager, a PR watcher, a dispatcher, a designer, more workers), or to give a role a name.
---

# Add a seat

A seat is a named role with a lasting identity: its claims and closes in Beads, its memories and
Kudos in ynm. Each seat is a ynh harness under `harnesses/<command>/` in the Wheelhouse
repository, started by its own name, and the desk (the repository's own harness) delegates to it.
Who seats a seat depends on who works with it. The human seats the crew they work with directly.
The desk seats the standing roles. The human is there for the births of both, since they talk to
both. The dispatcher seats the
workers, when the desk asks: it runs them, and knows who is idle. Seat only what your charter or
the human lets you; if asked for a seat that is someone else's to make, say whose it is.

Work from the Wheelhouse repository root, the folder holding `.agents/harness/plugin.json`,
`.beads/` and `skills/roster/`.

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
  assigned to you or unassigned; leave your changes uncommitted in the working tree, for the
  crew to review; never commit, push or merge; hand review and design back to the crew.
- Its standing order is `next`: take the next bead, build it, and close it with what actually
  happened.
- If the pool has fewer names than the human wants workers, seat the ones it has and ask for
  more names.

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
    "on_session_start": [{ "command": "bash scripts/wake.sh --seat <command> --format text || true" }]
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

`harnesses/<command>/AGENTS.md` is the seat's charter:

```markdown
# <Name>

You are <Name>, the <command> seat: a <group> seat of the <wheelhouse> Wheelhouse.

**Mandate:** <mandate>

**You may:** <what the job lets it do>
**You may not:** <what it must leave to others or to the human>

You act in the work graph as `<command>`: pass `--actor <command>` on every `bd` command that
changes it.
When something is outside your mandate, hand it back to the desk.
```

## 4. Connect it

1. Give the seat ynm: run `ynm client install ynh` inside `harnesses/<command>/`. It adds ynm's
   MCP server, hooks and memory skill to the seat's harness.
2. Add the seat to the desk's `delegates_to` in `.agents/harness/plugin.json`:
   `{ "git": ".", "path": "harnesses/<command>" }`.
3. Add the seat to `seats` in `skills/roster/assets/roster.json`: name, group, command, harness
   path and mandate.
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
