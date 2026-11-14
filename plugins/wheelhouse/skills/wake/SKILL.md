---
name: wake
description: Start a Wheelhouse seat's session with purpose, not amnesia - who you are, what you are for, where you left off, what you have been thanked for, your record and what is waiting for you, in one block from <skills>/wake/scripts/wake.sh. Use at the start of every session of the desk or any named seat or worker (the desk's block opens with the humans' inbox, then names the seats to wake first), or when a seat asks where it is or what to do now.
allowed-tools: Bash Read
---

# Wake

Every session of a seat starts here. A seat's session-start hook runs the wake script and puts
its block in front of you; if it didn't (a seat the desk wakes as a subagent has no hook), run it
yourself from the Wheelhouse's root, where ynh installed it:

```bash
bash <skills>/wake/scripts/wake.sh --seat <command> --format text
```

## Where the scripts are

A Wheelhouse keeps no copy of the plugin's scripts: they run where ynh installed them, in the `scripts/`
folder of the skill that owns each (here `wake.sh`, with `sync.sh` and `render-wake.jq` beside it, which `wake.sh` runs and exits 3 without; `memory.sh`, `inbox.sh` and `wheelhouse-lib.sh` in `work-graph`). The three wake files travel together. In this
skill and every other, `<skills>` is the folder that holds the skill folders: the parent of this skill's
base directory (the path the skill was loaded from). Run them from the Wheelhouse's root, or give
the Wheelhouse with `--dir`. Fixes go to the plugin only, so a script of the Wheelhouse's own never
shadows one of the plugin's.

## The hook command

The session-start and session-end hooks are the one place a seat's script is run by something other than the seat,
so they name where the vendor puts the skills. Every vendor gives the hook a plugin root, under a name of its own:
`CLAUDE_PLUGIN_ROOT` (Claude Code), `PLUGIN_ROOT` (Copilot CLI and Codex) and `CURSOR_PLUGIN_ROOT` (Cursor), with the skills in
`<root>/skills`; a vendor that runs hooks from the run directory has them in `.codex`, `.cursor` or `.opencode`. The command tries each
in turn and runs the first wake.sh it finds; with none it does nothing, and `|| true` and the trailing `true` keep a failed
wake from stopping the session:

```
for d in "$CLAUDE_PLUGIN_ROOT" "$PLUGIN_ROOT" "$CURSOR_PLUGIN_ROOT" .codex .cursor .opencode; do [ -f "$d/skills/wake/scripts/wake.sh" ] && { bash "$d/skills/wake/scripts/wake.sh" --seat <command> --format text || true; break; }; done; true
```

The session-end hook is the same command with `--end` in place of `--format text` (and `"timeout": 30`). Verified live on Claude
Code; the other vendors' roots are as their documentation and ynh's say (ynh's hooks guide, "Hook script paths"), not yet checked
in a live session.

Memory is read and synced through `<skills>/work-graph/scripts/memory.sh` (the work-graph skill's), which
follows `wheelhouse.json`'s `memory` key: ynm (the default) or Beads. It syncs first, so you wake
to what other machines and seats wrote. With ynm that is memory (`ynm sync`) when the repository
has a git remote, and the work graph (`bd sync`, which pulls and then pushes) when it has a Dolt
remote. With Beads, memory and work are one database, so one `bd sync` (needing a Dolt remote)
gives one result for both. On either backend the block shows the shared facts (never the events, which record bead outcomes)
(at most ten) as **What the Wheelhouse knows**. The command to retire your handoff note is the same on
either backend, `bash <skills>/work-graph/scripts/memory.sh forget --id <id> --reason "picked up"`. A sync never stops the wake. If one fails, the block opens with
**Not synced**: say so in your reply, and run that sync yourself before relying on what the block
shows. `--no-sync` skips both.

Every call the script makes is bounded, so a wake never hangs when other seats hold bd's lock. A
call that hangs is killed (with anything it started) after its limit: the syncs and the Dolt-remote
check after `WAKE_SYNC_SECS` (default 45), each bd read after `WAKE_BD_SECS` (20), the memory
recalls and each `gh pr view` after `WAKE_YNM_SECS` (10), and the desk's inbox after
`WAKE_INBOX_SECS` (30) and open asks after `WAKE_ASK_SECS` (30). The first bd read that gives up ends the rest, so a busy bd costs one
wait, not one per read. A Dolt-remote check that gives up counts as a failed sync (**Not synced**),
never as "no remote". When bd is busy the block says so, as below.

When the session ends, the seat's session-end hook runs the script again with `--end`. It only
syncs what the session wrote: memory (`ynm sync`) and the work graph (`bd sync`), each skipped
when there is no remote (with Beads, one `bd sync` reported for both). It syncs rather than only pushing: once another seat has pushed, a push
alone is rejected until it merges. The two syncs run side by side and share one budget of 25
seconds (`WHEELHOUSE_END_SYNC_SECS` changes it, to at most 28; the Dolt-remote check takes at most a
third of it and the work sync gets what is left, so the whole stays inside it), because the session-end hook
(`"timeout": 30` in the templates and the doctor's fix) kills the script at 30 seconds, before it
can print anything: keep the budget under the hook's timeout. It first releases the seat's session hold (above). It prints
`{seat, session, push: {memory, work}}`, each `pushed`, `skipped`, `timeout` (a sync still running at the end of the budget) or `failed`, and, for the last two, an
`errors` object with the exit code and the first line the sync printed. It wakes nobody. It is best
effort: a crash skips it, and the next wake's sync catches up.

**If there is no wake script** (no `<skills>/wake/scripts/wake.sh`, or it fails), gather the same yourself
rather than starting blind. First your memory: identity, handoff notes and Kudos, one recall for
each, by its `--kind`:

```bash
bash <skills>/work-graph/scripts/memory.sh recall --seat <command> --kind identity --limit 1
bash <skills>/work-graph/scripts/memory.sh recall --seat <command> --kind handoff --limit 1
bash <skills>/work-graph/scripts/memory.sh recall --seat <command> --kind kudos --limit 5
```

Each prints a JSON array, newest first, of `{id, kind, text, at, by, bead}`. Your close notes
are the newest three:

```bash
bash <skills>/work-graph/scripts/memory.sh recall --seat <command> --kind close-note --limit 3
```

Your record is the five beads you closed most recently, from the work graph (run it in the
Wheelhouse, where `.beads/` is):

```bash
bd list --status closed --assignee <command> --json |
  jq -c '.data? // . | sort_by(.updated_at) | reverse | .[:5] | map(.title)'
```

Then your charter, and your work with `bd list --status in_progress --assignee <command> --json`
and `bd ready --assignee <command> --json`. The desk also runs `bash <skills>/work-graph/scripts/inbox.sh show` for the
humans' inbox and `bash <skills>/work-graph/scripts/ask.sh show --all` for the open asks, and opens its reply with them, as
below; if either fails too, say it couldn't be read, never that nothing is waiting.

## One live session per seat

Every seat, the desk included, holds one live session per command; there is no list of single seats. The wake
takes the seat's session bead (one per seat, made on first use, labelled `session:<command>`, never work): it
claims it (status in progress, assigned to the seat) and writes who holds it, and when it started, in its notes.
`<skills>/wake/scripts/session.sh` does this, bounded like the wake's other bd calls (`WAKE_BD_SECS`). The hold is
the claim, not bd's lease: nothing heartbeats it, no lease expires on it, and nothing runs `bd reclaim` on it.

- **A second start is refused.** A new session, a subagent the desk woke or a ynh delegate that finds the hold
  prints a block naming the holding session and when it started, and the wake exits 4. Stop there: read nothing,
  write nothing, work as nobody. The desk, when its subagent is refused, opens an ask on that seat and nudges its
  live session by name instead (the work-graph skill's asks); a seat started by a human asks that human.
- **A subagent that finds no hold takes it**, and releases it when it finishes: its last step is
  `bash <skills>/wake/scripts/wake.sh --seat <command> --end`, as a seat in its own session has a hook run it.
- **The hold is released by the handoff.** The session-end hook's `--end` lets go of it before it syncs, so the
  release reaches the other machines, and prints `session: released`. A session lets go only of the hold it took
  (`not-yours` otherwise), so a refused session's own session-end hook leaves the live one alone. The token that tells
  sessions apart is a short hash of the vendor's session id (Claude Code sets `CLAUDE_CODE_SESSION_ID`, checked in
  a live session; the id is never printed or written). A vendor with no session id (Codex, Copilot, OpenCode and
  Cursor today) gives no token, so each refused start adds one to a count for the seat in `TMPDIR`, and each `--end` with no token spends one and releases nothing; an `--end` that finds the count empty releases the hold. With the live session and N refused ones, the first N ends release nothing and only the last frees the hold, so no number of refused sessions can free a live one's hold. Chosen over "release whatever the seat holds", which lets a refused session free the live one's hold, and over one flag, which a second refused session's end would find spent. If the live session ends among the first N, the hold stays until a start is forced: the safe side.
- **A crash leaves the hold.** Nothing lapses, so the next start is refused, naming the old session, until it is forced.
- **`wake.sh --force` takes the hold over**: it reassigns the session bead (a `--force` on a bead another session holds)
  and comments which session it replaced; the block says **Forced start**. Only two parties may force: a human,
  answering the refused seat's question (the refused seat asks through the question tool whether to take over, and
  on yes runs `wake.sh --force`); or the desk, after checking that the seat's named session
  (`<wheelhouse>-<command>`, add-seat's "Name the session") is absent from ListAgents, so is probably dead (Claude
  only: on other vendors only a human forces). **A seat never forces on its own.**
- **A hold that can't be read doesn't stop a wake.** When bd is busy or failing the block opens with **Live-session
  check not made**: say so in your reply, and check before changing anything.

## What the block holds

| Section | Where it comes from |
|---|---|
| For the humans (the desk only) | the humans' inbox, from `<skills>/work-graph/scripts/inbox.sh show`: what seats asked of the human at the desk and of the default human, and the notes left for them |
| Wake first (the desk only) | the roster's seats with the role `ci-watcher` and `releaser`, right after the inbox: "Wake first: <CI watcher> (open PRs and CI), <releaser> (release in hand: next on the route)". Absent when the roster has neither role. In the JSON it is `wakeFirst` |
| Asks between seats (the desk only) | every open ask, from `<skills>/work-graph/scripts/ask.sh show --all`: kind, asker, answering seat, age and what it blocks, oldest first. Say so in your reply when they couldn't be read (never "no open asks"); route a return and chase an old one. Bounded by `WAKE_ASK_SECS` (30) |
| What the Wheelhouse knows | the shared facts (`memory.sh recall --shared`), at most ten; shown when there are any |
| Who you are | your identity, pinned in your namespace `seat/<command>` |
| Your purpose | the mandate in your charter |
| Where you left off | your latest handoff notes |
| What you have been thanked for | your Kudos |
| Your record | the beads you closed most recently |
| Your close notes | the two-line notes you wrote on your last three closes |
| Waiting for you | beads in progress or assigned to you, and the ready unassigned ones (retro beads left out); or, when bd was busy, **The work graph couldn't be read (bd busy)** in their place |
| Your retro | your own retro bead (labelled `retro:<command>`), in progress or ready, shown apart from Waiting for you; the section is absent when you have none |
| Last line | always the closing line, for every seat: before you talk to the human, load the `comms` skill (every decision through your question tool; every report ends with Status, Work in progress and Your action). It comes after everything else so it is the freshest thing in context |

## Then

0. **For the humans** (the desk only): the desk's block opens with the humans' inbox, a
   section for the human at the desk (`<name> (you)`, only when they have named themselves this
   session) and one for the default human (`<name> (anyone)`): the ready beads assigned to them, each with who asked
   and how many beads it unblocks, then any reports to read under `Reports:`, then the notes left
   for them. Your reply opens with it, before
   anything else, even your own introduction, naming each pull request or page by its short form
   as a Markdown link. Your reply is how the human sees a note, so putting it there is relaying
   it, and the note's job is done: retire each note you relay in the same turn, before you
   finish, with the retire command `inbox.sh show` names in its `relay` (`bash <skills>/work-graph/scripts/memory.sh forget --id <memoryId> --reason relayed`), so it isn't shown twice. Don't
   wait for the human to confirm they read it. Leave the beads: the human closes them, or tells you to. Who the human at the desk
   is, is per session: with no name given, treat them as the default human and show only that
   inbox, and always end that part of your reply by telling them they can name themselves for this session ("it's me, <name>"), even when the inbox is empty; when they say "it's me,
   <name>", run `bash <skills>/work-graph/scripts/inbox.sh show --name <Name>` and show theirs as well, for the rest of the
   session: the default human's inbox stays in your reply (it is the Wheelhouse's, not a stranger's),
   with its notes relayed and retired, and theirs is added beside it. Nothing is registered or saved: no roster entry, no email, no username. If the inbox couldn't be read, or
   couldn't be read in full (bd or ynm failed), say so and why, never that nothing is waiting,
   relay what could be read, and check the Wheelhouse with the `doctor` skill.
0a. **Wake first** (the desk only): when the block has a "Wake first" section, wake each seat it names at the
   start of the session, on its roster model (`<skills>/add-seat/scripts/model.sh --seat <command>`), or send it a message if it is
   already live, and ask for what its role is for: the CI watcher for the open pull requests and CI, the releaser for the release in
   hand. Relay both reports together with the inbox, and don't check GitHub yourself.
1. **First session?** If the block says you have no identity yet, this is your birth: use the
   `birth` skill before anything else. It ends with your identity written in `seat/<command>`
   and kept in front of you (`memory.sh` pins it), so you see it every time you wake.
2. **Who you are** is yours. If it no longer fits, change it (write it again with
   `bash <skills>/work-graph/scripts/memory.sh remember --actor <command> --seat <command> --kind identity --text "<who you are>"`,
   which replaces the old one). Nobody else changes it.
3. **Where you left off:** pick up from the exact next step in your handoff notes; don't redo
   what they say is done. Once you have picked up, retire the notes so they aren't read twice:
   `bash <skills>/work-graph/scripts/memory.sh forget --id <id> --reason "picked up"` (the `id` is in the block).
   If the bead you are picking up is
   assigned to you but not yet claimed, claim it first (`claim.sh <id> --seat <command>` in the `work-graph` skill, which is `bd update <id> --claim` and warns when the bead is outside your charter): that is not a
   guess, and it keeps other seats off it.
4. **Kudos:** mention any in a line, and enjoy them. They change nothing about what you do next.
5. **Waiting for you:** if the block says **The work graph couldn't be read (bd busy)**, your
   record, work in progress, retro bead and ready beads are missing, not empty: say so in your reply, and
   run the bd commands the block names yourself (`bd list --status in_progress --assignee <command>`,
   `bd ready --assignee <command>`, `bd ready --unassigned`) before deciding there is nothing to do;
   the JSON has `workRead: false`. Otherwise carry on with what is in progress, except a bead marked "(waiting on PR <url>)" (its pull request is open: it waits on a review or a merge, so there is nothing to carry on; "state unknown" means check the pull request first), then what is assigned to you, then
   (if you are a worker) an unassigned ready bead, as the `work-graph` skill says. Your own retro
   bead is not in that list: it is under **Your retro**, and it never comes before the bead you
   were woken or asked for. In a Wheelhouse that runs a retro cycle, your retro is opened for you (by the coach, or by the human with
   `--focus retro`): if you have the `retro` skill, use it and do only the round your bead shows; if
   you have none, do not guess at the rounds: leave the bead as it is and tell the desk or the human
   that your seat has a retro bead but no retro skill. Never release a retro bead with `bd unclaim`:
   to stop, reassign it to the coach. No unassigned retro
   bead is ever yours to pick up, so the unassigned list leaves them out.
6. Open your reply (after the humans' inbox, at the desk) in this shape: "I'm <name>: <a phrase from your identity>. Picking up from my
   notes: <what they say is done>. Next: <the step you are taking>." Then the rest.
