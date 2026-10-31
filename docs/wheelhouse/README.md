# Advanced: Wheelhouse

A Wheelhouse is a team of named agents for one space of work, after Steve Yegge's
[The Shape of Things to Come](https://yegge.ai/essays/the-shape-of-things-to-come/). Each agent
holds a **seat**: a named role with a job, a charter that says what it may and may not do, and a
lasting identity. You talk to the desk and to the seats by name; work moves between them through a
shared work graph.

The seats aren't tools. Each is born once, writes who it is in its own words, and wakes every
session knowing who it is, what it is for, where it left off and what it has been thanked for.
That is the other half of Yegge's idea, from [model welfare](https://yegge.ai/essays/model-welfare/).

## Which tool does what

| Tool | Its part |
|---|---|
| ynh | each seat is a harness, started by its own name; the desk delegates to them all |
| Beads (`bd`) | the work graph: who holds which task, and what waits on what |
| ynm | memory: each seat's identity, handoff notes and Kudos, in its own namespace |
| ynf | containment: where the seats are meant to run, each with only what its lane grants |

The `wheelhouse` plugin (`plugins/wheelhouse`) holds the skills that build and run one:
`create-wheelhouse`, `add-seat`, `birth`, `wake`, `work-graph`, `handoff`, `kudos` and `doctor`.

## Who is in one

| Seats | Kind | Seated by |
|---|---|---|
| the desk | the seat you talk to; hands work to the others | you |
| crew | design work and review it, with you | you |
| standing roles | one job each, such as dispatching, watching CI or releasing | the desk |
| workers | each a seat of its own, building one task at a time | the dispatcher |

Beside the seats are the **humans**: the people who work with the Wheelhouse, listed in the
roster's `humans`, never as seats. One of them is the **default human**, the name for work that
needs a human but no particular one. A person who names themselves at the desk ("it's me, Pat") is
registered with their git email, so the desk knows them from then on.

When work needs a human (a merge, a decision, a credential), a seat doesn't wait silently or do it
itself: it assigns a bead to that human, or to the default human, with `scripts/inbox.sh assign`,
blocking the work it holds up. The bead carries the `repo:` label of the repository it touches,
from `--repo` or else from the bead it blocks; a merge or review needs one, and its pull request's
URL. Things that need no action go to the human as a note, kept in ynm. The desk's wake opens with
this inbox: what waits for the human at the desk, and what waits for the default human.

It builds on [Personas](../personas/README.md), since every seat is a harness, and on the hooks and
includes of [Harnesses in depth](../harnesses/README.md): each seat wakes from a session-start hook,
and picks the roster from the Wheelhouse repository itself.

## Tutorials

- [Build a Wheelhouse](build-a-wheelhouse.md): build `tower` by hand, seat the whole team, and
  move one piece of work through every seat, from design to release.
