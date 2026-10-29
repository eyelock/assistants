# assistants docs

`eyelock/assistants` is a personal library of agent skills and plugins, and a set of demos of the
YN tools fitted together in different ways: [ynh](https://github.com/eyelock/ynh) harnesses,
ynm memory, Beads work graphs and ynf containment. It is not production software.

The docs follow the repo's areas. The first four are the pieces; the two advanced areas show
what the pieces add up to.

| Area | What it shows |
|---|---|
| [Library](library/README.md) | skills and plugins you can install in any vendor tool: development workflow, languages, infrastructure, voice, media |
| [Personas](personas/README.md) | one agent composed from the library for a kind of work, with ynh |
| [Harnesses in depth](harnesses/README.md) | how a harness works: tools, hooks, the manifest, vendors and safety |
| [Testing and CI](testing/README.md) | how skills, harnesses and tutorials are checked |
| [Advanced: Triage](triage/README.md) | the same questions about what needs you, answered across every platform |
| [Advanced: Wheelhouse](wheelhouse/README.md) | a team of named agents sharing a work graph and memory |

Inside each area, the pages follow [Diataxis](https://diataxis.fr): tutorials teach by doing,
how-to guides solve a task, reference states facts, and explanation gives understanding. A page
is only ever one of those.

## Where to start

- **New here:** [What is in the repo](start/whats-in-the-repo.md), then
  [Install a plugin](library/install-a-plugin.md).
- **Want to see a harness work:** [Run a persona](personas/run-a-persona.md).
- **Want to make something:** [Write a skill with evals](library/write-a-skill-with-evals.md), or
  [Build a persona harness](personas/build-a-persona-harness.md).
- **Want to know why it is built this way:** [Architecture](start/architecture.md), then
  [Agentic features](start/agentic-features.md).
- **Want a guided tour with no model needed:** [Follow a request](harnesses/follow-a-request.md).

The terms are in the [Glossary](start/glossary.md).

## Viewing these docs

Run `make docs` in the repository root and open http://localhost:3000.
