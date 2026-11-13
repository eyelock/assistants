# wheelhouse

A Wheelhouse is a bespoke set of named agents for one space, such as developing a set of tools or
running your day. The pattern comes from Steve Yegge's
[The Shape of Things to Come](https://yegge.ai/essays/the-shape-of-things-to-come/), built here
from parts that work on any vendor:

| Layer | Built with |
|---|---|
| Seats: named roles, each with only the tools its job needs | [ynh](https://github.com/eyelock/ynh) harnesses, one per seat |
| The desk: the seat you talk to | the Wheelhouse repository's own harness, delegating to the seats |
| Work: tasks, dependencies, claims, an honest record | [Beads](https://github.com/steveyegge/beads), one graph per Wheelhouse |
| Memory: facts, handoff notes, what happened | [ynm](https://github.com/eyelock/ynm) |
| Models: what each seat starts on | the roster, by vendor-agnostic tier (`fast`, `balanced`, `deep`) with per-vendor overrides, applied at launch with `--model` or the Agent tool's `model` |
| Who's who | a `roster` skill in the Wheelhouse repository: its naming pools, the seats, and the humans who work with it, one of them the default human |
| The humans' inbox | beads assigned to a human and notes left for them in ynm, through `scripts/inbox.sh`, shown at the desk's wake |
| Shared helpers | `skills/work-graph/scripts/wheelhouse-lib.sh`: the one place the scripts' common helpers live (`limited`, `die`, `need`, the `bd` envelope, the roster path, backend detection, the seat tests, the model tiers), sourced by every script from beside itself or from the work-graph skill's `scripts/` folder (ynh delivers only skill folders, so the library rides in a skill every seat picks) |

## Skills

| Skill | Use it to |
|---|---|
| `create-wheelhouse` | start a Wheelhouse: its constitution, roster, desk, work graph and memory |
| `add-seat` | add a named seat: its harness, charter, standing orders, model and roster entry; one seat at a time, each a trial on a branch with a draft pull request until the human makes it official or drops it (a throwaway sandbox the human names as one skips the trial); a seat other than the desk picks the wheelhouse skills, leaving `refresh` out; the starter team's roles are offered one at a time: designer, reviewer, dispatcher, CI watcher, releaser, an optional programme manager, an optional verifier, workers and optional specialist workers; `scripts/model.sh` resolves the model a seat launches with |
| `work-graph` | find, claim, break down and close work in Beads, as a named seat; ask a human for what only a human can do (a merge, a decision, a credential) with a bead in their inbox, labelled with the repository it touches; give them reports to read, listed last; and leave them notes; read and write seat and human memory through `scripts/memory.sh`, over ynm or Beads as `wheelhouse.json` says; link every build bead to its tracker item (GitHub issue, JIRA key, other) as the Wheelhouse's `tracker.json` says, and read its release from the item; open draft pull requests with `scripts/open-pr.sh`, which sets the release and the closing link and refuses a bead with no tracker item |
| `handoff` | end a session by writing your own notes and asking to restart, and pick up from them |
| `kudos` | pass praise on to a seat, with no work attached, and read it when the seat wakes |
| `birth` | a seat's first session: read its charter, meet the team, write who it is in its own words |
| `wake` | start every session with purpose: identity, mandate, handoff notes, Kudos, record and waiting work; the desk's wake opens with the humans' inbox |
| `patrol` | diff the Wheelhouse's pull requests, issues and CI against the last patrol and print only what changed, so a CI watcher on a 5-minute timer wakes only for news |
| `refresh` | the desk's, after a pull: map the git diff to the `ynh install`s, the `ynh trust accept local/<seat>` for each seat ynh no longer counts as trusted, and the restarts it needs, run the safe steps and the doctor, and report any seat not installed or born |
| `comms` | talk to the humans: never name one in anything written, ask decisions through the question tool with options, one question at a time, a synopsis beside every bead id, post bodies from a file and never an unquoted heredoc, the outcome first |
| `doctor` | check ynm and Beads are set up right for a Wheelhouse, and the humans: one default human, the inbox script, no bead assigned to anyone outside the roster and the seats on trial (a harness on the checked-out branch), and a model for every seat |
| `vet-skill` | vet and pin a skill someone else wrote before a seat includes it: publisher and license, every file read, a SkillSpector scan of the folder as included, a full commit SHA, a `pinned-skills.md` record; and the one-finding exception rule, accepted only by a human in their own message and never granted by a worker |
| `diataxis` | write, restructure and review documentation with the Diataxis framework: tutorials, how-to guides, reference and explanation, each page exactly one kind; the framework text (Daniele Procida, CC-BY-SA 4.0) is pinned in the skill's `references/` |

## Setting up

Needs `ynh`, Beads (`brew install beads`) and, when memory is in ynm, `ynm` (`brew install eyelock/tap/ynh eyelock/tap/ynm`). `create-wheelhouse` asks where Agent Tasks (Beads) and Agent Memory (ynm or Beads) live, and records the answer in `wheelhouse.json`.

- Start Beads with `bd init --skip-agents --non-interactive --role maintainer`. In a terminal,
  `bd init` otherwise asks questions. Without `--skip-agents`, Beads writes its own agent
  setup, which tells agents to keep memory in `bd remember` instead of through `scripts/memory.sh`. `bd init` also commits the
  files it finds, so run it in a clean tree.
- With ynm memory, run `ynm init` in the Wheelhouse repository, and `ynm client install ynh` in each harness folder. With Beads memory, skip this and the next step.
- Beads takes over the repository's git hooks, so `ynm init` can't add its pre-push sync. Append
  `ynm sync` to `.beads/hooks/pre-push`, after the Beads block; the `doctor` skill prints the line.
- `.claude/settings.json` can't be changed from inside a Claude Code session, so remove any Beads
  hook there yourself.

Run the `doctor` skill to check all of this.
