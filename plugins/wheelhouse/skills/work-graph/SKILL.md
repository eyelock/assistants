---
name: work-graph
description: Work from a Wheelhouse's Beads work graph as a named seat - find the next ready task (work assigned to you first), claim it as yourself, dispatch ready work to idle workers, break work into dependent tasks, see who is working on what and what is blocking it, ask a human for what only a human can do (a merge, a decision, a credential) through the humans' inbox, and close tasks honestly with a note of what happened. Use when asked what's next or what to pick up, to dispatch or hand out work to workers, to split work into tasks, when work needs a human or the humans should be told something, who has or is working on a task, what is blocking a task or epic, or to mark work done, in a repository with a .beads/ folder. Not for GitHub or JIRA issues.
allowed-tools: Bash Read
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
6. Say which bead you claimed and what you are about to do. Keep the claim alive
   ([Keeping your claim](#keeping-your-claim)).

## Keeping your claim

A claim carries a lease that runs out five minutes after the claim or the last heartbeat, and `bd show`
says when ("Lease: expires in 4 mins"). The lease is `bd`'s own and its length is not configurable,
so a Wheelhouse cannot lengthen it: seats refresh it.

- **Heartbeat while you hold a bead:** `bd heartbeat <id> --actor <you>` (alias `bd hb`) at least
  every few minutes, and at every natural pause, such as before a long build, a test run or a
  review wait. It writes no history, so the cadence costs nothing, and only the holder can refresh.
  A seat that cannot heartbeat for a long stretch (one blocking command) hands off rather than
  letting the lease run out.
- **What a lapsed lease does on its own:** nothing. The bead stays in progress and assigned to its
  holder, and another seat's `--claim` is still refused. It only looks abandoned in `bd show`
  ("Lease: expired"). Nothing reclaims it on a timer: it stays held until the dispatcher acts. A
  seat that sees a lapsed claim, its own or another's, tells the dispatcher (or the desk, where
  there is none) and leaves the bead alone.
- **The dispatcher reclaims, and only then.** Once it has confirmed the holder is gone (no live
  session, and the lease long expired), it runs `bd reclaim --id <id> --older-than <grace>`,
  records on the bead why it did, and re-dispatches it. The bead goes back to ready with no
  assignee, another seat can claim it, and the old holder's `bd heartbeat` is refused. A refused
  heartbeat means you lost the bead: stop, tell the dispatcher, and don't edit it.
- **Never run `bd reclaim` or `bd update --force` on another seat's bead.** Only the dispatcher
  reclaims, and only for a seat it has confirmed is gone.

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
   The one exception is a reclaim after confirming the holder is gone ([Keeping your
   claim](#keeping-your-claim)): record why on the bead, then dispatch it again as in step 6.
8. Report who got what, who is still idle, and what is left unassigned. With a tracker, each
   dispatch note names the bead's item, its release, and whether its pull request closes the item
   or is part of it, read from `scripts/open-pr.sh --dir <the Wheelhouse> --bead <id> --dry-run`
   (`item`, `release`, `relation`), the logic the worker's pull request will use. It is a snapshot taken now: `open-pr.sh`
   recomputes it when the PR opens, and that result wins. Without a
   tracker (`kind: none` or no `tracker.json`), for a `housekeeping` bead with no item, or for a
   bead in an exempt repository (`"exempt": true` in the output), the note has no tracker line. A bead the script refuses (no item, or no release) isn't handed out:
   leave it unassigned and say why. On exit 3 (a fault, not a refusal), report it to the desk and
   dispatch nothing.
9. When you wake a worker for its bead, start it on its roster model: the Agent tool's `model`
   parameter for a subagent, `--model` for a launcher, both from the `add-seat` skill's
   `scripts/model.sh --seat <worker>`.

## Breaking work down

1. Create the epic: `bd create "<goal>" -t epic -p <0-4> --json`.
2. Create each task under it: `bd create "<task>" --parent <epic> -l repo:<repo> -d "<what done looks like>" --json`,
   with `--external-ref` set to its tracker item (see "Linking the tracker").
   Every task names the one repository it touches in a `repo:` label, such as `repo:api` or
   `repo:docs`. Split a task that touches two. The one exception is a bead for a human (see
   "Needing a human") whose work touches no repository, such as a decision.
3. Order them: `bd dep add <later> <earlier>` makes `<later>` wait for `<earlier>`. Add a link only
   where the order matters; tasks that can run side by side stay unlinked.
4. Check the shape: `bd ready --json` should list only the tasks that can start now.
5. Report the epic, its tasks in order and what is ready first. Don't claim them unless asked.

## Linking the tracker

A Wheelhouse may have a tracker (GitHub Issues, JIRA or another) for the humans' project view,
beside the work graph. Its config is `tracker.json` at the Wheelhouse root; the shape, and how to
read it, is in [references/tracker.md](references/tracker.md). Nothing here assumes a particular
tracker: use the config's names and the adapter's commands.

1. **A build bead links its tracker item.** `external_ref` holds the item's full URL or key, as
   the config's `item.reference` says: `bd create ... --external-ref "<reference>"`, or
   `bd update <id> --external-ref "<reference>"`. File the tracker item first, then cut the bead.
   Never cut a build bead with the field empty, except as rule 2 says.
2. **Only housekeeping beads, and beads in an exempt repository, go without.** Housekeeping is work
   with no place in the humans' project view: tidying the work graph, refreshing a seat. Add the
   label (`-l housekeeping`) when creating one. A bead whose `repo:` label is in the config's
   `exempt_repos` needs no item either (rule 4). A merge, review or decision bead for a human is
   not a build bead and needs no item.
3. **The release comes from the item, never the bead.** Read it with the tracker adapter's
   `release <item>` (`scripts/tracker-<kind>.sh`); don't copy a milestone, fixVersion or version onto the bead, where it would go stale
   when the humans move the item.
4. **With no tracker** (`kind: "none"`, or no `tracker.json`) there is nothing to link: leave
   `external_ref` empty, and don't invent a reference. The same holds for a bead in an **exempt
   repository**: one whose `repo:` label is named in the config's `exempt_repos` (a Wheelhouse's
   own repository, say, which plans in beads). It needs no item, and `open-pr.sh` opens its pull
   request with no issue, no closing link and no milestone.
5. **Check before you rely on it.** Never call an adapter on a reference that hasn't passed
   `item.pattern`. `tracker.json` holds no commands, and nothing in it is ever run (see the
   reference). If a reference doesn't match, say so and ask
   the desk; don't edit it to fit.

## Opening a pull request

A worker that hands work over with a pull request opens it only with this skill's
`scripts/open-pr.sh`, never `gh pr create` by hand, so the PR carries its tracker item and release:

```bash
bash path/to/work-graph/scripts/open-pr.sh --dir <the Wheelhouse> --bead <id> \
  --title "<conventional title>" --body-file <file> --base <branch>
```

Run it from the repository's worktree; `--dir` is the Wheelhouse, where `tracker.json` and the
work graph are. Start the body file with your byline. The script:

1. reads the bead's `external_ref` and the release from the item (the adapter's `release`),
   and opens a **draft** PR with the release set where the tracker supports it (a GitHub
   milestone);
2. writes the tracker's own closing link at the end of the body: on GitHub, `Closes #N` when this
   bead is the last open bead on the item, `Part of #N` when others remain;
3. **refuses**, opening nothing and saying why, a bead with no `external_ref` that isn't labelled
   `housekeeping` and isn't in an exempt repository, a reference that doesn't match `item.pattern`, and an item with no release.
   Fix the cause (file the item, ask the desk to set its release) and run it again;
4. with no tracker (`kind: "none"`), still opens the PR, with no item and no release.

Everything GitHub-specific is in `scripts/tracker-github.sh`; another tracker gets a
`tracker-<kind>.sh` with the same two commands (`closing`, `pr-flags`), and until it does,
`tracker-generic.sh` names the item in the body and sets no release. `--dry-run` shows what it
would run. A PR with no tracker item of its own (a Wheelhouse process change, say) is a bead
labelled `housekeeping`; do not close a tracker item from it.

## Who's working on what

- In progress, with who has it: `bd list --status in_progress --json` (the `assignee` field).
- One seat's history: `bd list --assignee <name> --all --json`.
- One bead in full, with its audit trail and what it waits on: `bd show <id> --json`.
- What is blocking a task or an epic: `bd blocked --json`, or `bd show` each open child and read
  the `dependencies` whose `dependency_type` is `blocks`.

## Needing a human

Some work only a human can do: a merge, a decision, a credential. Never wait for it silently, and
never do it yourself. Ask through the humans' inbox, with the inbox script at the Wheelhouse root
(`scripts/inbox.sh`, a copy of this skill's), which takes every name from the roster:

1. **Who:** a named person only when you know who: they asked for the work, or they have named
   themselves at the desk this session. Otherwise the default human (`--to default`, the
   roster's human with `"default": true`), whom every desk shows. A named person is `--to
   <command>`, their name in lowercase; they need no roster entry. Never a name you guessed.
2. **Assign a bead** for it, blocking the work it holds up, so that work waits and its wait is
   visible:

   ```bash
   bash scripts/inbox.sh assign --from <your command> --to default \
     --title "Merge <repository> #<n>" --url <the pull request's URL> --blocks <your bead> \
     --repo <repository> \
     --description "<who asked, why, and what done means: merged, so <your bead> can go on>"
   ```

   It is created as you (`--from`), so the human sees who asked. A merge or review needs `--url`,
   or the script refuses it: find the pull request's URL, or ask for it. Don't invent one. Like
   every task, it carries the `repo:` label of the one repository it touches: `--repo`, or, left
   out, the `repo:` label of the bead it blocks. A merge or review is refused without one; a
   decision or credential that touches no repository goes without. A merge gets its own small
   bead, even when your own bead is about the same change. When you report it, name the pull
   request by its short form as a Markdown link, such as
   `[<repository> #12](https://github.com/<owner>/<repository>/pull/12)`.
3. **Give them something to read,** such as a weekly report or a milestone that moved, as a
   report: a bead labelled `inbox:report`, priority 3 unless you pass `--priority`, with no
   `--url` or repository needed. It stays in their inbox, listed after the merges, reviews and
   decisions, until the human closes it:

   ```bash
   bash scripts/inbox.sh assign --from <your command> --to default --kind report \
     --title "<what it reports>" --description "<the report>"
   ```

   `--priority <0-4>` sets any inbox bead's priority (0 highest); without it, a bead other than
   a report keeps bd's default, 2.
4. **Tell them things** that need no action with a note instead of a bead: it waits in their
   inbox, in ynm (namespace `human/<command>`, tagged `inbox`), until the desk relays it:

   ```bash
   bash scripts/inbox.sh note --from <your command> --to default --content "<the news>"
   ```

   Name anything on the web by its short form as a Markdown link, such as
   `[<repository> #12](https://github.com/<owner>/<repository>/pull/12)`, never a bare `#12` or
   a bare URL.
5. Then carry on with other ready work, or hand off: your blocked bead comes back to `bd ready`
   once the human closes theirs.

`bash scripts/inbox.sh show` prints what is waiting for the humans, and the desk's wake opens with
it. If bd or ynm fails, it exits 3 and names the failure in `errors`, still printing what the other
returned: a broken tool never reads as an empty inbox. Who is at the desk is per session: with no name, the desk shows the default
human's inbox; when someone names themselves ("it's me, <name>"), the desk runs
`bash scripts/inbox.sh show --name <Name>` for the rest of the session, which adds their inbox
(the beads assigned to their lowercase name, and the ynm notes in `human/<command>`). Nothing is
registered or written to the repository: no roster entry, no email, no username.

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
