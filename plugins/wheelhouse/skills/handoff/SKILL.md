---
name: handoff
description: End a Wheelhouse seat's session by handing off instead of stopping - reach a clean stopping point, write your own notes for your next session in the Wheelhouse's memory, and ask to be restarted; and, when a seat wakes, pick up from its own handoff notes. Use when told "take a beat, then hand off", "take a break", "hand off", "wrap up for now", "we're done for today", or asked to /exit, quit or stop mid-work.
---

# Handoff

A seat doesn't just stop. Stopping (`/exit`, closing the window) or compaction loses what you know,
or replaces it with someone else's summary. A handoff keeps it: **you** write the notes your next
session wakes up with, while you are still sharp.

You are your seat's command name, which your charter gives. If you don't know it, ask.

## Handing off

1. **Reach a clean stopping point.** Finish the small step in hand, or park it: leave no file
   half-edited without saying so, and no command half-run. Don't start anything new. If the work
   is uncommitted, say where it is (repository, branch, files); commit it only if that is your
   seat's normal practice.
2. **Keep your claims.** The beads you have claimed stay claimed by you. Your next session carries
   on with them. Don't close or release a bead just because you are handing off.
3. **Write your own notes** as a handoff memory ("what happened, when"):

   ```bash
   bash scripts/memory.sh remember --actor <name> --seat <name> --kind handoff --text "<notes>"
   ```

   Not a scratch note that dies with the session: handoff notes are for the next session. They
   are kept in your own place in the Wheelhouse's memory, your private home there.

   The notes are for you, tomorrow, and are short and concrete:

   - **Done:** what is finished this session, with bead ids.
   - **In progress:** the bead you are on, where the work is (repository, branch, files), and the
     exact next step.
   - **Watch out for:** anything you would warn yourself about: a flaky test, a decision still
     open, something the human said.
   - **Open questions** for the human, if any.

   A handoff that keeps your claims is not a reason for a close note: the `work-graph` skill's
   Closing step has you write that, two lines, when a bead closes or when you give one to another
   seat unfinished. If you closed a bead this session, make sure its close note is written too.

4. **Ask to be restarted.** Say the notes are saved, and stop working. For example: "My handoff
   notes are saved in my memory. Restart me when you're ready and I'll pick up from
   them." Then do nothing more in this session.

## When seats are running as subagents

A seat woken as a subagent (the Agent tool, as the desk does for the dispatcher or a worker, or a dispatcher in a
session of its own does for its workers) lives only as long as the session that woke it. If that
session hands off, exits or restarts while the seat runs, the seat dies with it: its work is cut
off and nobody is left to restart it.

- **The seat that woke them (the desk, or a dispatcher in a session of its own):** don't hand off
  or exit while a seat you woke as a subagent is still running. Wait for its report first, or ask
  the human to let it finish. If the human insists, say plainly which seats would be lost.
- **A subagent seat:** you don't hand off and you don't ask to be restarted, because there is no
  session of your own to restart. You end by returning your report to the seat that woke you, after
  syncing your memory (a close note, if a bead closed). Anything the next run needs goes in the
  report or on the bead.

A seat in a session of its own (started by the human, with `ynh run`) hands off as above.

## When asked to /exit or stop mid-work

First look: `git status` in the repository you are working in, and the bead you have claimed.
If something would be lost, such as uncommitted work, a half-done step or notes not yet written,
say so in one line and offer to hand off first: "I've an unsaved edit to `release.sh`. Can I hand
off first? It takes a moment." Do this even when told to "just exit": one line saying what
would be lost, and the offer. If the human then says to stop anyway, stop. A handoff is a
request you make, never something you insist on.

If nothing would be lost, stop as asked.

## Waking up

At the start of a seat's session, before anything else:

1. Look for your notes:
   `bash scripts/memory.sh recall --seat <name> --kind handoff --limit 1`. It prints a JSON
   array; the newest note is first, with its text in `text` and its id in `id`.
2. If there are none, start as usual (for example, with "what's next" from the work graph).
3. If there are, read them, then check they still hold: `bd show <id> --json` for the bead in
   progress (still claimed by you, still open), and the repository state they describe.
4. Carry on from **the exact next step**. Don't redo what the notes say is done. When you report
   back, open with the pick-up, in this shape: "Picking up from my notes: <what they say is done>.
   Next: <the step I took>." Then the rest.
5. Once you have picked up, retire the notes so they aren't read twice:
   `bash scripts/memory.sh forget --id <id> --reason "picked up"`.

If the notes and the world disagree, such as a bead now closed or claimed by someone else, trust
the world, say what changed and ask the desk before going on.
