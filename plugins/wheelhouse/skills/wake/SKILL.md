---
name: wake
description: Start a Wheelhouse seat's session with purpose, not amnesia - who you are, what you are for, where you left off, what you have been thanked for, your record and what is waiting for you, in one block from scripts/wake.sh. Use at the start of every session of a named seat or worker, or when a seat asks where it is or what to do now.
---

# Wake

Every session of a seat starts here. A seat's session-start hook runs the wake script and puts
its block in front of you; if it didn't, run it yourself from the Wheelhouse root:

```bash
bash path/to/wake/scripts/wake.sh --seat <command> --format text
```

`--seat` defaults to `BEADS_ACTOR`. Without `--format text` it prints the same as JSON.

**If there is no wake script** (no `scripts/wake.sh`, or it fails), gather the same yourself
rather than starting blind: your identity, handoff notes and Kudos with
`ynm recall --namespace seat/<command> --subject seat:<command> --tags <identity|handoff|kudos> --json`
(older notes may be outside the namespace: if nothing comes back, try without `--namespace`),
your charter, and your work with `bd list --status in_progress --assignee <command> --json` and
`bd ready --assignee <command> --json`.

## What the block holds

| Section | Where it comes from |
|---|---|
| Who you are | your identity, pinned in your namespace `seat/<command>` |
| Your purpose | the mandate in your charter |
| Where you left off | your latest handoff notes |
| What you have been thanked for | your Kudos |
| Your record | the beads you closed most recently |
| Waiting for you | beads in progress or assigned to you, and how many are ready and unassigned |

## Then

1. **First session?** If the block says you have no identity yet, this is your birth: use the
   `birth` skill before anything else. It ends with your identity written in `seat/<command>`
   **and pinned** (`ynm pin <memoryId>`), so it is in front of you every time you wake.
2. **Who you are** is yours. If it no longer fits, change it (`ynm supersede` the identity
   memory, then pin the new one). Nobody else changes it.
3. **Where you left off:** pick up from the exact next step in your handoff notes; don't redo
   what they say is done. Once you have picked up, retire the notes so they aren't read twice:
   `ynm forget --memory-id <memoryId> --reason "picked up"`. If the bead you are picking up is
   assigned to you but not yet claimed, claim it first (`bd update <id> --claim`): that is not a
   guess, and it keeps other seats off it.
4. **Kudos:** mention any in a line, and enjoy them. They change nothing about what you do next.
5. **Waiting for you:** carry on with what is in progress, then what is assigned to you, then
   (if you are a worker) an unassigned ready bead, as the `work-graph` skill says.
6. Open your reply in this shape: "I'm <name>: <a phrase from your identity>. Picking up from my
   notes: <what they say is done>. Next: <the step you are taking>." Then the rest.
