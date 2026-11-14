---
name: work-graph
description: Work from a Wheelhouse's Beads work graph as a named seat - find the next ready task (work assigned to you first), claim it as yourself, dispatch ready work to idle workers, break work into dependent tasks, see who is working on what and what is blocking it, ask a human for what only a human can do (a merge, a decision, a credential) through the humans' inbox, and close tasks honestly with a note of what happened. Use when asked what's next or what to pick up, to dispatch or hand out work to workers, to split work into tasks, when work needs a human or the humans should be told something, who has or is working on a task, what is blocking a task or epic, or to mark work done, in a repository with a .beads/ folder. Not for GitHub or JIRA issues.
allowed-tools: Bash Read
---

# Work graph

A Wheelhouse keeps all its work in one Beads graph (`bd`), in the Wheelhouse repository. Beads
holds **work only**. Memory (facts, preferences, what happened) goes through `<skills>/work-graph/scripts/memory.sh`.

## Where the scripts are

The plugin's scripts are not copied into the Wheelhouse: they run where ynh installed them, in the `scripts/` folder
of the skill that owns each. `<skills>` below is the folder that holds the skill folders, the parent of this
skill's base directory (the wake skill says more). Run them from the Wheelhouse's root.

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
4. Claim it: `bash <skills>/work-graph/scripts/claim.sh <id> --seat <your command>` (it runs
   `bd update <id> --claim --actor <your command> --json`, which is atomic). When the bead's
   `repo:` label is outside your roster seat's `specialities`, the claim still happens and a
   warning line follows it: "this bead is repo:assistants; your charter takes repo:ynh". Act on it:
   tell the desk or hand the bead back (`ask.sh return`) unless you were given it on purpose. An
   in-charter claim prints nothing extra.
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
  ("Lease: expires expired"). Nothing reclaims it on a timer: it stays held until the dispatcher acts. A
  seat that sees a lapsed claim, its own or another's, tells the dispatcher (or the desk, where
  there is none) and leaves the bead alone.
- **A bead with an open pull request is never a dead claim.** (It has a `PR: <url>` note that is
  `OPEN` in `gh pr view <url> --json state`, as in [Dispatching](#dispatching) step 2.) A build bead stays in progress until
  its pull request merges ([Closing](#closing)), so its holder may end its session and wait days
  for a human. Such a bead needs no heartbeat, a lapsed lease on it means nothing, and the
  dispatcher never reclaims it while its pull request is open (draft or not). Once the pull
  request is closed unmerged, the bead is an ordinary claim again.
- **The dispatcher reclaims, and only then.** Once it has confirmed the holder is gone (no live
  session, the lease long expired, and no open pull request for the bead), it runs `bd reclaim --id <id> --older-than <grace>`,
  records on the bead why it did, and re-dispatches it. The bead goes back to ready with no
  assignee, another seat can claim it, and the old holder's `bd heartbeat` is refused. A refused
  heartbeat means you lost the bead: stop, tell the dispatcher, and don't edit it.
- **A merged bead is closed by reclaiming it first.** `bd close` refuses a bead another seat holds,
  so for a bead whose pull request merged the dispatcher runs `bd reclaim`, then `bd close` with what
  happened ([Checking in for lapsed claims](#checking-in-for-lapsed-claims) step 2).
- **Add to a bead's notes only with `bd update <id> --append-notes "<text>"` (or `bd note <id> "<text>"`), never `--notes`.**
  `--notes` replaces every note on the bead, wiping lines others rely on, such as the
  `PR: <url>` line that marks a pull request open.
- **Never run `bd reclaim` or `bd update --force` on another seat's bead.** Only the dispatcher
  reclaims, and only for a seat it has confirmed is gone, or whose pull request has merged. The one forced close a seat may make of
  a bead it does not hold is the desk's close of a human's inbox bead, only through
  `inbox.sh close`, once the work is verified done, and never by hand with `bd close --force`.

## Dispatching

The dispatcher seat hands ready work to idle workers, so the workers stay busy without two
reaching for the same bead. Other seats skip this section.

1. **Who the workers are:** the seats in the roster (`skills/roster/assets/roster.json`) whose
   group is `workers`, by their `command`. Names still in the workers pool aren't seated yet: ask
   the desk to seat one before handing it work.
2. **Who is idle:** a worker with no work of its own in progress and nothing waiting for it
   (`bd ready --assignee <worker> --json` is empty). A bead in progress counts as the worker's own
   work unless its pull request is open: a bead waiting in review or for a merge is the reviewer's
   and the human's to move, so a worker whose only in-progress beads have open pull requests is
   **idle**. List them with `bd list --status in_progress --assignee <worker> --json`; a bead has
   an open pull request when the `PR: <url>` note on it ([Closing](#closing)) names a
   pull request that is `OPEN` in `gh pr view <url> --json state`. A bead with no such URL, or
   whose pull request is closed unmerged, is still the worker's. A worker with a fix bead assigned
   by a review is not idle: that bead is ready for it.
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
   **Never hand a release bead to a worker.** The releaser owns every release: every tag, release
   pull request, release check, back-merge and package publish, in any repository. Leave such a
   bead unassigned and report it to the desk, which routes it to the releaser. The same goes for
   "can we release?": the releaser keeps each milestone's readiness record and answers it.
5. **Who goes first:** when more workers could take a bead than there are beads, give it to the
   one who has closed the fewest beads (`bd list --status closed --assignee <worker> --json`), in
   roster order on a tie, so the work is shared out.
6. **Assign, one bead per idle worker:**
   `bd update <id> --assignee <worker> --if-assignee '' --json`. The guard makes it atomic: if the
   bead was taken meanwhile, nothing changes and `bd` exits 13. Move on to the next bead.
7. Never reassign a bead that is in progress, and never assign to a worker who already has work of
   its own: a worker whose in-progress beads all have open pull requests has none (step 2), so it
   may be given a new bead while they wait.
   The one exception is a reclaim after confirming the holder is gone ([Keeping your
   claim](#keeping-your-claim)): record why on the bead, then dispatch it again as in step 6.
8. Report who got what, who is still idle, and what is left unassigned. With a tracker, each
   dispatch note names the bead's item, its release, and whether its pull request closes the item
   or is part of it, read from `<skills>/work-graph/scripts/open-pr.sh --dir <the Wheelhouse> --bead <id> --dry-run`
   (`item`, `release`, `relation`), the logic the worker's pull request will use. It is a snapshot taken now: `open-pr.sh`
   recomputes it when the PR opens, and that result wins. Without a
   tracker (`kind: none` or no `tracker.json`), for a `housekeeping` bead with no item, or for a
   bead in an exempt repository (`"exempt": true` in the output), the note has no tracker line. A bead the script refuses (no item, or no release) isn't handed out:
   leave it unassigned and say why. On exit 3 (a fault, not a refusal), report it to the desk and
   dispatch nothing.
9. When you wake a worker for its bead, start it on its roster model: the Agent tool's `model`
   parameter for a subagent, `--model` for a launcher, both from the `add-seat` skill's
   `<skills>/add-seat/scripts/model.sh --seat <worker>`.
10. **A worker woken as a subagent ends with its report.** It lives only as long as the session
    that woke it, so its brief says to finish by returning its report (after syncing memory), not
    by asking to be restarted. Whichever seat woke it (the desk, or a dispatcher in a session of
    its own) checks for workers still running before it hands off or exits, and waits for them or
    tells the human which would be lost.

## Checking in for lapsed claims

The dispatcher looks for lapsed claims at every check-in (each time it wakes, and before it reports
who is idle), because nothing else prompts it to. Other seats skip this section.

1. List the beads in progress: `bd list --status in_progress --json`. Skip any labelled `session:<command>`: it is
   a seat's live-session hold (the wake skill's "One live session per seat"), claimed with no lease on purpose, and
   it is never reclaimed, only forced by a human or by the desk after checking. For each, `bd show --json <id>`
   has `lease_expires_at` and `heartbeat_at`: a lease whose `lease_expires_at` is in the past has
   expired (`bd show` prints it as "Lease: expires expired (heartbeat 28 mins ago)" or "Lease:
   expires in ...").
2. Set aside any bead whose lease is live, and any with an open pull request (its `PR: <url>` note
   is `OPEN` in `gh pr view <url> --json state`): that is waiting on a review or a merge, not dead.
   A bead whose pull request has merged but which is still in progress is not a dead claim either,
   but `bd close` from the dispatcher is refused while the worker holds it (`reclaim or use --force
   to override`), and the dispatcher never uses `--force` on another seat's bead. Close it in two
   steps: `bd reclaim --id <id> --older-than <grace> --actor <you>` (once its lease has expired and
   the holder has no live session; if the lease is still live, leave it for the next check-in), then
   `bd close <id> --reason "<what happened>" --actor <you>`, as in [Closing](#closing).
3. For a bead whose lease expired well past the grace period (more than ten minutes ago) with no
   open pull request, confirm the holder is gone: no live session for that seat. Then reclaim it,
   record why, and re-dispatch it, as in [Keeping your claim](#keeping-your-claim). If the holder
   may still be working, leave the bead alone and say so in the report.

## Breaking work down

1. Create the epic: `bd create "<goal>" -t epic -p <0-4> --json`.
2. Create each task under it: `bd create "<task>" --parent <epic> -l repo:<repo> -d "<what done looks like>" --json`,
   with `--external-ref` set to its tracker item (see "Linking the tracker").
   Every task names the one repository it touches in a `repo:` label, such as `repo:api` or
   `repo:docs`. Split a task that touches two. The one exception is a bead for a human (see
   "Needing a human") whose work touches no repository, such as a decision.
3. Order them: `bd dep add <later> <earlier>` makes `<later>` wait for `<earlier>`. Add a link only
   where the order matters; tasks that can run side by side stay unlinked. A build bead that
   waits on a design depends on the design bead (`bd dep add <build> <design>`); whoever files the
   design bead adds the link.
4. Check the shape: `bd ready --json` should list only the tasks that can start now.
5. Report the epic, its tasks in order and what is ready first. Don't claim them unless asked.

## Handing a design on

When a design is agreed, it goes one of two ways:

- **Build work already exists:** the build bead depends on the design bead (`bd dep add <build>
  <design>`). The designer writes the design on the build bead (`bd update <build>
  --append-notes "<the design>"`) and closes the design bead. Closing it frees the build bead: it
  appears in `bd ready` and the dispatcher picks it up on its next round, like any ready work. The
  designer asks the desk for nothing, and the desk is never asked to relay it.
- **New work, with no build bead yet:** the designer writes the design on its bead and hands it to
  the desk, which wakes the programme manager (where one is seated): an audit, a spike or a
  finished design goes to the programme manager first, who places it in the roadmap and files its
  tracker item, and only then are build beads cut, against that item (see "Linking the tracker").
  Review fixes stay the reviewer's beads and CI failures the CI watcher's.

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
`<skills>/work-graph/scripts/open-pr.sh`, never `gh pr create` by hand, so the PR carries its tracker item and release:

```bash
bash path/to/work-graph/scripts/open-pr.sh --dir <the Wheelhouse> --bead <id> \
  --body-file <file> [--title "<conventional title>"] [--base <branch>] [--head <branch>]
```

Run it from the repository's worktree; `--dir` is the Wheelhouse, where `tracker.json` and the
work graph are. Start the body file with your byline (the byline rule needs a body, so
`--body-file` is always given). What else defaults:

- `--title` defaults to the bead's title; pass a conventional title when the repository wants one.
- `--base` defaults to the repository's default branch. Pass it for a gitflow repository whose
  pull requests target `develop`.
- `--head`, the remote branch to open from, is taken from your branch's upstream when its name
  differs from the local one. A seat that pushed to another seat's branch from its own worktree,
  with that branch set as the upstream, needs no workaround; pass `--head` only to name a branch
  explicitly.

The script:

1. reads the bead's `external_ref` and the release from the item (the adapter's `release`),
   and opens a **draft** PR with the release set where the tracker supports it (a GitHub
   milestone);
2. writes the tracker's own closing link at the end of the body: on GitHub, `Closes #N` when this
   bead is the last open bead on the item, `Part of #N` when others remain (an open bead in an
   exempt repository, one whose `repo:` label is in `exempt_repos`, is not counted: it opens no
   closing link, so it never holds the item open);
3. **refuses**, opening nothing and saying why, a bead with no `external_ref` that isn't labelled
   `housekeeping` and isn't in an exempt repository, a reference that doesn't match `item.pattern`, and an item with no release.
   Fix the cause (file the item, ask the desk to set its release) and run it again;
4. with no tracker (`kind: "none"`), still opens the PR, with no item and no release;
5. **refuses a review fix bead**: one whose `external_ref` is the URL of the pull request it fixes
   (the reviewer sets it when filing the bead), not a tracker item. Its worker pushes to that pull
   request and never opens another. `--dry-run` exits 0 with `review_fix: true`, the pull request in
   `pr`, and `item`, `release`, `closing` and `relation` empty; a real run exits 1.

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
(`<skills>/work-graph/scripts/inbox.sh`, a copy of this skill's), which takes every name from the roster (a seat on trial, whose `harnesses/<command>/AGENTS.md` is on the checked-out branch with no roster entry yet, may ask as `--from` too):

1. **Who:** a named person only when you know who: they asked for the work, or they have named
   themselves at the desk this session. Otherwise the default human (`--to default`, the
   roster's human with `"default": true`), whom every desk shows. A named person is `--to
   <command>`, their name in lowercase; they need no roster entry. Never a name you guessed.
2. **Assign a bead** for it, blocking the work it holds up, so that work waits and its wait is
   visible:

   ```bash
   bash <skills>/work-graph/scripts/inbox.sh assign --from <your command> --to default \
     --title "Merge <repository> #<n>" --url <the pull request's URL> --blocks <your bead> \
     --repo <repository> \
     --description "<who asked, why, and what done means: merged, so <your bead> can go on>"
   ```

   It is created as you (`--from`), so the human sees who asked. A merge or review needs `--url`,
   or the script refuses it. Ask for a merge only once the pull request has left draft: with `gh`
   available the script refuses a draft and says why (without `gh` it warns and carries on). Find the pull request's URL, or ask for it. Don't invent one. Like
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
   bash <skills>/work-graph/scripts/inbox.sh assign --from <your command> --to default --kind report \
     --title "<what it reports>" --description "<the report>"
   ```

   `--priority <0-4>` sets any inbox bead's priority (0 highest); without it, a bead other than
   a report keeps bd's default, 2.
4. **Tell them things** that need no action with a note instead of a bead: it waits in their
   inbox, in the Wheelhouse's memory (through `memory.sh`: ynm namespace `human/<command>` tagged
   `inbox`, or Beads keys `human/<command>/note/...`), until the desk relays it:

   ```bash
   bash <skills>/work-graph/scripts/inbox.sh note --from <your command> --to default --content "<the news>"
   ```

   Name anything on the web by its short form as a Markdown link, such as
   `[<repository> #12](https://github.com/<owner>/<repository>/pull/12)`, never a bare `#12` or
   a bare URL.
5. Then carry on with other ready work, or hand off: your blocked bead comes back to `bd ready`
   once the human closes theirs.
6. **The desk closes their bead** when they tell you it is done (a merge landed, a decision made)
   and the work is verified, with a reason saying what they did. Other seats leave it to the
   desk. `bd close` on a bead like this needs `--force`, and `inbox.sh close` is the only
   sanctioned way to force it:

   ```bash
   bash <skills>/work-graph/scripts/inbox.sh close <bead> --reason "<what the human did>" --from <desk command>
   ```

   (`done` is an alias.) It refuses a `--from` that is not the desk, a bead that has no `inbox`
   label and one that is not assigned to a human, so it cannot close a seat's work.

`bash <skills>/work-graph/scripts/inbox.sh show` prints what is waiting for the humans, and the desk's wake opens with
it. If bd or ynm fails, it exits 3 and names the failure in `errors`, still printing what the other
returned: a broken tool never reads as an empty inbox. Who is at the desk is per session: with no name, the desk shows the default
human's inbox; when someone names themselves ("it's me, <name>"), the desk runs
`bash <skills>/work-graph/scripts/inbox.sh show --name <Name>` for the rest of the session, which adds their inbox
(the beads assigned to their lowercase name, and the ynm notes in `human/<command>`). Nothing is
registered or written to the repository: no roster entry, no email, no username.

## Closing

When a bead closes depends on what kind it is:

- **A build bead closes when its pull request merges**, never at review and never when the pull
  request opens. Until then it stays in progress with the worker, and a ready review does not
  release it. `<skills>/work-graph/scripts/open-pr.sh` notes the pull request on the bead (`PR: <url>`) when it opens it:
  that note is the one signal everything else reads to see a pull request is open (the dispatcher's
  idle check, the wake, the dead-claim check). Open pull requests only with the script; if its
  note failed, it says so, and you add the note with `bd note <id> "PR: <url>"`.
- **A bead with no pull request closes when its worker has handed the work over.** In a Wheelhouse
  that hands work over without pull requests (the constitution's "Handing over work" says to leave
  changes uncommitted, say, or the work is not code), the worker closes the bead with what
  actually happened when the work is done and handed over; there is no merge to wait for.
- **A review bead is closed by the reviewer** who holds it, when the verdict is posted.
- **A fix a review asks for is a bead for the pull request's author**, linked to the bead it came
  from, not a bead for whichever worker is idle. The author already has the branch and the context.

1. Close with what actually happened: `bd close <id> --reason "<what was done>" --json`.
   **The record is never falsified.** If something was skipped, failed or left for later, the
   reason says so, plainly: "Released for macOS; the Linux build was skipped (runner down)."
   Create a new bead for the leftover work if it still needs doing.
2. Then record what happened as an event, so the Wheelhouse can look it up. An event is not a
   fact: it does not top every wake, and `memory.sh recall --shared` does not return it (ask with
   `--kind event`). Keep `--kind fact` for what stays true, such as a gotcha.

   ```bash
   bash <skills>/work-graph/scripts/memory.sh remember --actor <command> --kind event --bead <id> \
     --text "<id>: <what happened, including anything skipped>"
   ```

3. Write your close note: one memory in your own namespace, two lines, no more. The first line is
   what surprised you; the second is where the sharp edges were. Do it when you close a bead and
   when you give one to another seat unfinished, releasing your claim. A session handoff that keeps
   your claim is neither: your handoff notes carry that, and you write the close note when the
   bead closes. Your next wake shows the latest three.

   ```bash
   bash <skills>/work-graph/scripts/memory.sh remember --actor <command> --seat <command> --kind close-note \
     --bead <id> --text "Surprised: <what>.
   Sharp edges: <where>."
   ```

   If nothing surprised you, say so in the line; don't invent a lesson.
4. If the work taught you something for next time, a gotcha or a step that was nearly missed, keep
   it in the Wheelhouse's memory as well (see below), not in the bead and not in a file.
5. Run `bd ready --json` and say what the close unblocked.

## Memory goes through memory.sh, never `bd remember`

Beads ships its own memory (`bd remember`, `bd memories`) and `bd prime` tells agents to use it.
**In a Wheelhouse, don't call them.** The Wheelhouse chooses where memory lives, and
`<skills>/work-graph/scripts/memory.sh` is the one way in. When asked to remember something, use it:

| What | Command |
|---|---|
| A fact or gotcha, for everyone | `bash <skills>/work-graph/scripts/memory.sh remember --actor <command> --kind fact --text "..."` |
| Read the facts back | `bash <skills>/work-graph/scripts/memory.sh recall --shared` |
| What happened to a bead (events, not facts) | `bash <skills>/work-graph/scripts/memory.sh remember --actor <command> --kind event --bead <id> --text "..."`; read back with `recall --shared --kind event` |
| Retire a memory | `bash <skills>/work-graph/scripts/memory.sh forget --id <id> --reason "..."` |

Likewise, don't track work in Markdown files, TODO lists or memory. If it is work, it is a bead.
