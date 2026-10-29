---
name: work-graph
description: Work from a Wheelhouse's Beads work graph as a named seat - find the next ready task (work assigned to you first), claim it as yourself, dispatch ready work to idle workers, break work into dependent tasks, see who is working on what and what is blocking it, and close tasks honestly with a note of what happened. Use when asked what's next or what to pick up, to dispatch or hand out work to workers, to split work into tasks, who has or is working on a task, what is blocking a task or epic, or to mark work done, in a repository with a .beads/ folder. Not for GitHub or JIRA issues.
---

# Work graph

A Wheelhouse keeps all its work in one Beads graph (`bd`), in the Wheelhouse repository. Beads
holds **work only**. Memory (facts, preferences, what happened) goes to ynm.

## Who you are

In a seat, you are its command name, which your charter gives. Pass `--actor <command>` on every
command that changes a bead, so claims and closes are recorded as you, whatever `BEADS_ACTOR`
holds. Outside a seat (no charter names one), leave `--actor` off and Beads records the human.
Never act as another seat.

Add `--json` to every `bd` command and read the result, rather than parsing the table output.

## What's next

1. **Work assigned to you comes first.** `bd ready --assignee <name> --json` lists ready beads
   someone (such as the dispatcher) has given you. Take the first of those.
2. Otherwise, `bd ready --unassigned --json` lists ready beads nobody holds. Never take a bead
   assigned to another seat, even when it is ready and yours would wait. If your roster seat
   lists `specialities`, take only beads carrying one of those labels, and leave the rest for
   the dispatcher, even when they are more urgent.
3. Skip epics: they close when their children do. Take the task with the highest priority (`0` is
   highest), and the oldest when priorities tie.
4. Claim it: `bd update <id> --claim --json`. The claim is atomic.
5. **If the claim is refused**, someone else holds it. Take the next ready bead. Never reassign,
   reopen or edit a bead another seat has claimed; if it looks stuck, tell the desk.
6. Say which bead you claimed and what you are about to do.

## Dispatching

The dispatcher seat hands ready work to idle workers, so the workers stay busy without two
reaching for the same bead. Other seats skip this section.

1. **Who the workers are:** the seats in the roster (`skills/roster/assets/roster.json`) whose
   group is `workers`, by their `command`. Names still in the workers pool aren't seated yet: ask
   the desk to seat one before handing it work.
2. **Who is idle:** a worker with nothing in progress (`bd list --status in_progress --assignee
   <worker> --json` is empty) and nothing waiting for it (`bd ready --assignee <worker> --json` is
   empty).
3. **What to hand out:** `bd ready --unassigned --json`, tasks only (no epics), highest priority
   first. Leave review and design beads to the crew: hand out only work a worker can do alone.
4. **Who can take it:** a worker whose roster seat lists `specialities` is a specialist. Each
   speciality is a bead label, such as `repo:ynh` or `lang:go`, and a specialist takes only
   beads carrying one of its labels. A worker with no `specialities` is general purpose, and
   takes anything. For each bead, in order:
   - **specialist first:** an idle worker with a speciality the bead carries;
   - **fall through:** if every such worker is busy, an idle general-purpose worker;
   - **fall back:** if no worker has the speciality, an idle general-purpose worker.
   Never give a bead to a specialist whose specialities it doesn't carry. If nobody can take it, leave it
   unassigned and say why; if there is no general-purpose worker at all, say the Wheelhouse
   should have one.
5. **Who goes first:** when more workers could take a bead than there are beads, give it to the
   one who has closed the fewest beads (`bd list --status closed --assignee <worker> --json`), in
   roster order on a tie, so the work is shared out.
6. **Assign, one bead per idle worker:**
   `bd update <id> --assignee <worker> --if-assignee '' --json`. The guard makes it atomic: if the
   bead was taken meanwhile, nothing changes and `bd` exits 13. Move on to the next bead.
7. Never reassign a bead that is in progress, and never assign to a worker who already has work.
8. Report who got what, who is still idle, and what is left unassigned.

## Breaking work down

1. Create the epic: `bd create "<goal>" -t epic -p <0-4> --json`.
2. Create each task under it: `bd create "<task>" --parent <epic> -l repo:<repo> -d "<what done looks like>" --json`.
   Every task names the one repository it touches in a `repo:` label, such as `repo:api` or
   `repo:docs`. Split a task that touches two.
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
