---
name: handoff
description: End a Wheelhouse seat's session by handing off instead of stopping - reach a clean stopping point, write your own notes for your next session in ynm, and ask to be restarted; and, when a seat wakes, pick up from its own handoff notes. Use when told "take a beat, then hand off", "take a break", "hand off", "wrap up for now", or asked to /exit, quit or stop mid-work, and when a seat's session begins with a handoff waiting.
---

# Handoff

A seat doesn't just stop. Stopping (`/exit`, closing the window) or compaction loses what you know,
or replaces it with someone else's summary. A handoff keeps it: **you** write the notes your next
session wakes up with, while you are still sharp.

You are your seat's command name, such as `gahan` (`BEADS_ACTOR` holds it). If you don't know it,
ask.

## Handing off

1. **Reach a clean stopping point.** Finish the small step in hand, or park it: leave no file
   half-edited without saying so, and no command half-run. Don't start anything new. If the work
   is uncommitted, say where it is (repository, branch, files); commit it only if that is your
   seat's normal practice.
2. **Keep your claims.** The beads you have claimed stay claimed by you. Your next session carries
   on with them. Don't close or release a bead just because you are handing off.
3. **Write your own notes** as one episodic memory in ynm ("what happened, when"):

   ```bash
   ynm remember --type episodic --level distributed --namespace seat/<name> \
     --subject seat:<name> --tags handoff --content "<notes>"
   ```

   Not `working` memory: ynm keeps that in one session's namespace and drops it when the session
   ends, and handoff notes are for the next session. They go in your own namespace,
   `seat/<name>`: your private home in the Wheelhouse's memory.

   The notes are for you, tomorrow, and are short and concrete:

   - **Done:** what is finished this session, with bead ids.
   - **In progress:** the bead you are on, where the work is (repository, branch, files), and the
     exact next step.
   - **Watch out for:** anything you would warn yourself about: a flaky test, a decision still
     open, something the human said.
   - **Open questions** for the human, if any.

4. **Ask to be restarted.** Say the notes are saved, and stop working. For example: "My handoff
   notes are saved in ynm (subject seat:gahan). Restart me when you're ready and I'll pick up from
   them." Then do nothing more in this session.

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
   `ynm recall --namespace seat/<name> --subject seat:<name> --tags handoff --type episodic --limit 1 --json`. It
   prints a JSON array; the newest note is first, and its id is in `memoryId`.
2. If there are none, start as usual (for example, with "what's next" from the work graph).
3. If there are, read them, then check they still hold: `bd show <id> --json` for the bead in
   progress (still claimed by you, still open), and the repository state they describe.
4. Carry on from **the exact next step**. Don't redo what the notes say is done. When you report
   back, start with two or three lines on where you picked up: what the notes said was done, and
   the step you took next.
5. Once you have picked up, retire the notes so they aren't read twice:
   `ynm forget --memory-id <memoryId> --reason "picked up"`.

If the notes and the world disagree, such as a bead now closed or claimed by someone else, trust
the world, say what changed and ask the desk before going on.
