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
| Who's who | a `roster` skill in the Wheelhouse repository: its naming pools, the seats, and the humans who work with it, one of them the default human |
| The humans' inbox | beads assigned to a human and notes left for them in ynm, through `scripts/inbox.sh`, shown at the desk's wake |

## Skills

| Skill | Use it to |
|---|---|
| `create-wheelhouse` | start a Wheelhouse: its constitution, roster, desk, work graph and memory |
| `add-seat` | add a named seat: its harness, charter, standing orders and roster entry |
| `work-graph` | find, claim, break down and close work in Beads, as a named seat; ask a human for what only a human can do (a merge, a decision, a credential) with a bead in their inbox, labelled with the repository it touches; give them reports to read, listed last; and leave them notes |
| `handoff` | end a session by writing your own notes and asking to restart, and pick up from them |
| `kudos` | pass praise on to a seat, with no work attached, and read it when the seat wakes |
| `birth` | a seat's first session: read its charter, meet the team, write who it is in its own words |
| `wake` | start every session with purpose: identity, mandate, handoff notes, Kudos, record and waiting work; the desk's wake opens with the humans' inbox |
| `doctor` | check ynm and Beads are set up right for a Wheelhouse, and the humans: one default human, the inbox script, and no bead assigned to anyone outside the roster |

## Setting up

Needs `ynh`, `ynm` (`brew install eyelock/tap/ynh eyelock/tap/ynm`) and Beads (`brew install beads`).

- Start Beads with `bd init --skip-agents --non-interactive --role maintainer`. In a terminal,
  `bd init` otherwise asks questions. Without `--skip-agents`, Beads writes its own agent
  setup, which tells agents to keep memory in Beads rather than ynm. `bd init` also commits the
  files it finds, so run it in a clean tree.
- Run `ynm init` in the Wheelhouse repository, and `ynm client install ynh` in each harness folder.
- Beads takes over the repository's git hooks, so `ynm init` can't add its pre-push sync. Append
  `ynm sync` to `.beads/hooks/pre-push`, after the Beads block; the `doctor` skill prints the line.
- `.claude/settings.json` can't be changed from inside a Claude Code session, so remove any Beads
  hook there yourself.

Run the `doctor` skill to check all of this.
