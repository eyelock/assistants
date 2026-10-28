---
name: add-seat
description: Add a named seat to a Wheelhouse - a crew member, a standing role (such as a dispatcher) or the worker fleet - as a ynh harness with its charter, standing orders and only the tools its job needs, named from the Wheelhouse's roster. Use when asked to add, create or set up a seat, role, worker or agent in a Wheelhouse (a release manager, a PR watcher, a dispatcher, a designer, more workers), or to give a role a name.
---

# Add a seat

A seat is a named role with a lasting identity: its claims and closes in Beads, its memories and
Kudos in ynm. Each seat is a ynh harness under `harnesses/<command>/` in the Wheelhouse
repository, and the desk (the repository's own harness) delegates to it.

Work from the Wheelhouse repository root, the folder holding `.agents/harness/plugin.json`,
`.beads/` and `skills/roster/`.

## 1. Pin down the role

You need three things. Ask for any you can't tell from the request, one question at a time:

- **Group:** crew (designs work and reviews it), standing (one mandate, runs unattended) or
  worker (implements ready beads; workers are a fleet, see below).
- **Mandate:** one sentence, the job and nothing else, such as "Cuts releases when asked, and
  nothing else."
- **Reach:** the repositories and platforms the job touches, and whether it only reads them or
  also changes them.

## Workers are a fleet

Workers are interchangeable, so they share **one** harness, `harnesses/worker/`, run as many named
instances: `BEADS_ACTOR=<worker> ynh run harnesses/worker --focus next`, where `<worker>` is the
worker's command, its name in lowercase (`BEADS_ACTOR=okafor`, never `Okafor`). Each instance is a worker
from the workers pool, claiming and closing as its own name.

- The first time workers are asked for, create the fleet harness (step 3, with `worker` as the
  command and the charter below), and connect it (step 4). The roster's `seats` gets one entry
  for the fleet: `{ "name": "Workers", "group": "workers", "command": "worker", "harness":
  "harnesses/worker", "mandate": "..." }`.
- After that, "add a worker" creates nothing: say which worker names the pool has, and how to
  start each one. If the pool has fewer names than the human wants workers, ask for more names.
- The fleet's charter says: you are the worker named by `BEADS_ACTOR` (or by whoever started
  you; ask if neither says), you work only on beads assigned to you or unassigned, and you hand
  review and design back to the crew.

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
  "env_passthrough": ["BEADS_ACTOR"],
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
  MCP servers, and the environment variables they need in `env_passthrough`. A seat that only
  reads a platform gets its read-only server.
- One focus per standing order. Each prompt names the seat, and says what to do and when to stop.
- The `on_session_start` hook wakes the seat with purpose: it runs the Wheelhouse's
  `scripts/wake.sh` (copied there by `create-wheelhouse` from the `wake` skill), and the seat
  starts with who it is, where it left off, its Kudos and what is waiting for it. A named seat's
  hook names it (`--seat <command>`); the worker fleet's leaves `--seat` out, so each worker is
  named by `BEADS_ACTOR`.

`harnesses/<command>/AGENTS.md` is the seat's charter:

```markdown
# <Name>

You are <Name>, the <command> seat: a <group> seat of the <wheelhouse> Wheelhouse.

**Mandate:** <mandate>

**You may:** <what the job lets it do>
**You may not:** <what it must leave to others or to the human>

You claim and close beads as `<command>`. If `BEADS_ACTOR` is unset, pass `--actor <command>`.
When something is outside your mandate, hand it back to the desk.
```

## 4. Connect it

1. Give the seat ynm: run `ynm client install ynh` inside `harnesses/<command>/`. It adds ynm's
   MCP server, hooks and memory skill to the seat's harness.
2. Add the seat to the desk's `delegates_to` in `.agents/harness/plugin.json`:
   `{ "git": ".", "path": "harnesses/<command>" }`.
3. Add the seat to `seats` in `skills/roster/assets/roster.json`: name, group, command, harness
   path and mandate.
4. Check the Wheelhouse with the `doctor` skill if it is available.

The seat's first session is its **birth** (the `birth` skill): it reads its charter, meets the
team and writes who it is, in its own words. Don't write its identity for it.

## 5. Report

Say who the seat is (name, group, mandate), what it can reach, its standing orders, and how to
start it: `BEADS_ACTOR=<command> ynh run harnesses/<command> --focus <order>`. Don't commit
unless asked.
