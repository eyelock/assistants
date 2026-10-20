# assistants docs

`eyelock/assistants` is a reference library of agent skills, plugins and [ynh](https://github.com/eyelock/ynh) harnesses. It is not production software. It shows how the agentic features fit together: agent skills, plugins and marketplaces, MCP servers, hooks, and harnesses with profiles and focuses.

The docs have three tracks. Pick the one that matches what you want to do. Inside each track the pages follow [Diataxis](https://diataxis.fr): tutorials teach by doing, how-to guides solve a task, reference states facts, and explanation gives understanding. A page is only ever one of those.

| I want to... | Go to |
|---|---|
| Install and use the skills, plugins and harnesses | [Use](use/README.md) |
| Make my own skills, plugins and harnesses | [Build](build/README.md) |
| Understand how the features work | [Learn](learn/README.md) |

## Where to start

- **Never used any of this:** [What is in the repo](use/explanation/whats-in-the-repo.md), then [Install a plugin](use/tutorials/install-a-plugin.md).
- **Want to see a harness work:** [Run a persona](use/tutorials/run-a-persona.md).
- **Want to make something:** [Build a persona harness](build/tutorials/build-a-persona-harness.md), or [Write a skill with evals](build/tutorials/write-a-skill-with-evals.md).
- **Want to know why it is built this way:** [Architecture](learn/explanation/architecture.md), then [Agentic features](learn/explanation/agentic-features.md).
- **Want a guided tour with no model needed:** [Follow a request](learn/tutorials/follow-a-request.md).

## Viewing these docs

Run `make docs` in the repository root and open http://localhost:3000.
