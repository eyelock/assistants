---
name: wake
description: Start a Wheelhouse seat's session with purpose, not amnesia - who you are, what you are for, where you left off, what you have been thanked for, your record and what is waiting for you, in one block from scripts/wake.sh. Use at the start of every session of a named seat or worker, or when a seat asks where it is or what to do now.
---

# Wake

Every session of a seat starts here. A seat's session-start hook runs the wake script and puts
its block in front of you; if it didn't (a seat the desk wakes as a subagent has no hook), run the
Wheelhouse's own copy yourself, `scripts/wake.sh` at the Wheelhouse root:

```bash
bash scripts/wake.sh --seat <command> --format text
```

From any other directory, give the script's full path and the Wheelhouse with `--dir`:
`bash <wheelhouse>/scripts/wake.sh --dir <wheelhouse> --seat <command> --format text`. `<command>`
is your own, the name in your roster entry, or, for a seat on trial (its `harnesses/<command>/AGENTS.md` on the checked-out branch, no roster entry yet), the name of its harness folder: it wakes from that harness as group `trial`, and a command with neither is refused, the message naming the harness path it looked for; the bare name (`bash scripts/wake.sh <command>`) works
too. `--seat` defaults to `BEADS_ACTOR`, and with neither the script stops and lists the roster's
seats. Without `--format text` it prints the same as JSON.

Memory is read and synced through `scripts/memory.sh` (copied from the work-graph skill), which
follows `wheelhouse.json`'s `memory` key: ynm (the default) or Beads. It syncs first, so you wake
to what other machines and seats wrote. With ynm that is memory (`ynm sync`) when the repository
has a git remote, and the work graph (`bd sync`, which pulls and then pushes) when it has a Dolt
remote. With Beads, memory and work are one database, so one `bd sync` (needing a Dolt remote)
gives one result for both. On either backend the block shows the shared facts (never the events, which record bead outcomes)
(at most ten) as **What the Wheelhouse knows**. The command to retire your handoff note is the same on
either backend, `bash scripts/memory.sh forget --id <id> --reason "picked up"`. A sync never stops the wake. If one fails, the block opens with
**Not synced**: say so in your reply, and run that sync yourself before relying on what the block
shows. `--no-sync` skips both.

When the session ends, the seat's session-end hook runs the script again with `--end`. It only
syncs what the session wrote: memory (`ynm sync`) and the work graph (`bd sync`), each skipped
when there is no remote (with Beads, one `bd sync` reported for both). It syncs rather than only pushing: once another seat has pushed, a push
alone is rejected until it merges. The two syncs run side by side and share one budget of 25
seconds (`WHEELHOUSE_END_SYNC_SECS` changes it, to at most 28), because the session-end hook
(`"timeout": 30` in the templates and the doctor's fix) kills the script at 30 seconds, before it
can print anything: keep the budget under the hook's timeout. It prints
`{seat, push: {memory, work}}`, each `pushed`, `skipped`, `timeout` (a sync still running at the end of the budget) or `failed`, and, for the last two, an
`errors` object with the exit code and the first line the sync printed. It wakes nobody. It is best
effort: a crash skips it, and the next wake's sync catches up.

**If there is no wake script** (no `scripts/wake.sh`, or it fails), gather the same yourself
rather than starting blind. First your memory: identity, handoff notes and Kudos, one recall for
each, by its `--kind`:

```bash
bash scripts/memory.sh recall --seat <command> --kind identity --limit 1
bash scripts/memory.sh recall --seat <command> --kind handoff --limit 1
bash scripts/memory.sh recall --seat <command> --kind kudos --limit 5
```

Each prints a JSON array, newest first, of `{id, kind, text, at, by, bead}`. Your close notes
are the newest three:

```bash
bash scripts/memory.sh recall --seat <command> --kind close-note --limit 3
```

Your record is the five beads you closed most recently, from the work graph (run it in the
Wheelhouse, where `.beads/` is):

```bash
bd list --status closed --assignee <command> --json |
  jq -c '.data? // . | sort_by(.updated_at) | reverse | .[:5] | map(.title)'
```

Then your charter, and your work with `bd list --status in_progress --assignee <command> --json`
and `bd ready --assignee <command> --json`. The desk also runs `bash scripts/inbox.sh show` for the
humans' inbox and opens its reply with it, as below; if that fails too, say the inbox couldn't be
read, never that nothing is waiting.

## What the block holds

| Section | Where it comes from |
|---|---|
| For the humans (the desk only) | the humans' inbox, from `scripts/inbox.sh show`: what seats asked of the human at the desk and of the default human, and the notes left for them |
| What the Wheelhouse knows | the shared facts (`memory.sh recall --shared`), at most ten; shown when there are any |
| Who you are | your identity, pinned in your namespace `seat/<command>` |
| Your purpose | the mandate in your charter |
| Where you left off | your latest handoff notes |
| What you have been thanked for | your Kudos |
| Your record | the beads you closed most recently |
| Your close notes | the two-line notes you wrote on your last three closes |
| Waiting for you | beads in progress or assigned to you, and how many are ready and unassigned |

## Then

0. **For the humans** (the desk only): the desk's block opens with the humans' inbox, a
   section for the human at the desk (`<name> (you)`, only when they have named themselves this
   session) and one for the default human (`<name> (anyone)`): the ready beads assigned to them, each with who asked
   and how many beads it unblocks, then any reports to read under `Reports:`, then the notes left
   for them. Your reply opens with it, before
   anything else, even your own introduction, naming each pull request or page by its short form
   as a Markdown link. Your reply is how the human sees a note, so putting it there is relaying
   it, and the note's job is done: retire each note you relay in the same turn, before you
   finish, with the retire command `inbox.sh show` names in its `relay` (`bash scripts/memory.sh forget --id <memoryId> --reason relayed`), so it isn't shown twice. Don't
   wait for the human to confirm they read it. Leave the beads: the human closes them, or tells you to. Who the human at the desk
   is, is per session: with no name given, treat them as the default human and show only that
   inbox, and always end that part of your reply by telling them they can name themselves for this session ("it's me, <name>"), even when the inbox is empty; when they say "it's me,
   <name>", run `bash scripts/inbox.sh show --name <Name>` and show theirs for the rest of the
   session. Nothing is registered or saved: no roster entry, no email, no username. If the inbox couldn't be read, or
   couldn't be read in full (bd or ynm failed), say so and why, never that nothing is waiting,
   relay what could be read, and check the Wheelhouse with the `doctor` skill.
1. **First session?** If the block says you have no identity yet, this is your birth: use the
   `birth` skill before anything else. It ends with your identity written in `seat/<command>`
   and kept in front of you (`memory.sh` pins it), so you see it every time you wake.
2. **Who you are** is yours. If it no longer fits, change it (write it again with
   `bash scripts/memory.sh remember --actor <command> --seat <command> --kind identity --text "<who you are>"`,
   which replaces the old one). Nobody else changes it.
3. **Where you left off:** pick up from the exact next step in your handoff notes; don't redo
   what they say is done. Once you have picked up, retire the notes so they aren't read twice:
   `bash scripts/memory.sh forget --id <id> --reason "picked up"` (the `id` is in the block).
   If the bead you are picking up is
   assigned to you but not yet claimed, claim it first (`bd update <id> --claim`): that is not a
   guess, and it keeps other seats off it.
4. **Kudos:** mention any in a line, and enjoy them. They change nothing about what you do next.
5. **Waiting for you:** carry on with what is in progress, except a bead marked "(waiting on PR <url>)" (its pull request is open: it waits on a review or a merge, so there is nothing to carry on; "state unknown" means check the pull request first), then what is assigned to you, then
   (if you are a worker) an unassigned ready bead, as the `work-graph` skill says.
6. Open your reply (after the humans' inbox, at the desk) in this shape: "I'm <name>: <a phrase from your identity>. Picking up from my
   notes: <what they say is done>. Next: <the step you are taking>." Then the rest.
