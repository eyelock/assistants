---
name: work-graph
description: Work from a Wheelhouse's Beads work graph as a named seat - find the next ready task, claim it as yourself, break work into dependent tasks, see who is working on what and what is blocking it, and close tasks honestly with a note of what happened. Use when asked what's next or what to pick up, to split work into tasks, who has or is working on a task, what is blocking a task or epic, or to mark work done, in a repository with a .beads/ folder. Not for GitHub or JIRA issues.
---

# Work graph

A Wheelhouse keeps all its work in one Beads graph (`bd`), in the Wheelhouse repository. Beads
holds **work only**. Memory (facts, preferences, what happened) goes to ynm.

## Who you are

You are your seat's command name, such as `gahan`. The seat's harness sets `BEADS_ACTOR` to it, so
claims and closes are recorded as you. If `BEADS_ACTOR` is unset, pass `--actor <name>` on every
command that changes a bead. If you don't know your seat's name, ask; never act as someone else.

Add `--json` to every `bd` command and read the result, rather than parsing the table output.

## What's next

1. `bd ready --json` lists open beads with no open blockers.
2. Skip epics: they close when their children do. Take the task with the highest priority (`0` is
   highest), and the oldest when priorities tie.
3. Claim it: `bd update <id> --claim --json`. The claim is atomic.
4. **If the claim is refused**, someone else holds it. Take the next ready bead. Never reassign,
   reopen or edit a bead another seat has claimed; if it looks stuck, tell the desk.
5. Say which bead you claimed and what you are about to do.

## Breaking work down

1. Create the epic: `bd create "<goal>" -t epic -p <0-4> --json`.
2. Create each task under it: `bd create "<task>" --parent <epic> -l repo:<repo> -d "<what done looks like>" --json`.
   Every task names the one repository it touches in a `repo:` label, such as `repo:ynh` or
   `repo:homebrew-tap`. Split a task that touches two.
3. Order them: `bd dep add <later> <earlier>` makes `<later>` wait for `<earlier>`. Add a link only
   where the order matters; tasks that can run side by side stay unlinked.
4. Check the shape: `bd ready --json` should list only the tasks that can start now.
5. Report the epic, its tasks in order and what is ready first. Don't claim them unless asked.

## Who's working on what

- In progress, with who has it: `bd list --status in_progress --json` (the `assignee` field).
- One seat's history: `bd list --assignee <name> --all --json`.
- One bead in full, with its audit trail and what it waits on: `bd show <id> --json`.
- What is blocking a task or an epic: `bd blocked --json`, or `bd show` each open child and read
  the `dependencies` whose `dependency_type` is `blocks`.

## Closing

1. Close with what actually happened: `bd close <id> --reason "<what was done>" --json`.
   **The record is never falsified.** If something was skipped, failed or left for later, the
   reason says so, plainly: "Released for macOS; the Linux build was skipped (runner down)."
   Create a new bead for the leftover work if it still needs doing.
2. Then leave an episodic memory in ynm, so the Wheelhouse learns from it:

   ```bash
   ynm remember --type episodic --level distributed --subject repo:<repo> \
     --tags bead,<id> --content "<id>: <what happened, including anything skipped>"
   ```

3. If the work taught you something for next time, a gotcha or a step that was nearly missed, keep
   it in ynm as well (see below), not in the bead and not in a file.
4. Run `bd ready --json` and say what the close unblocked.

## Memory goes to ynm, never Beads

Beads ships its own memory (`bd remember`, `bd memories`) and `bd prime` tells agents to use it.
**In a Wheelhouse, don't.** It would split memory across two stores. When asked to remember
something, use ynm:

| What | Command |
|---|---|
| A fact or gotcha | `ynm remember --type semantic --level distributed --content "..."` |
| How to do something | `ynm remember --type procedural --level distributed --content "..."` |
| What happened | `ynm remember --type episodic --level distributed --content "..."` |

Likewise, don't track work in Markdown files, TODO lists or ynm. If it is work, it is a bead.
