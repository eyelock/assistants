# Build

Make your own skills, plugins and harnesses with this repo as the pattern. The pages follow [Diataxis](https://diataxis.fr): tutorials teach by doing, how-to guides solve a task, and reference states facts. Understanding how the pieces work is in [Learn](../learn/README.md); installing and using what is here is in [Use](../use/README.md).

You need `ynh` and `ynd` v0.12.0 for most pages, and Claude Code for the ones that run a model. Pages that run a model say so, and each costs a few short requests at most.

## Tutorials

Learn by building something small, start to finish.

- [Build a persona harness](tutorials/build-a-persona-harness.md): compose a code-review persona from existing skills with includes, a profile and a focus, and run it
- [Write a skill with evals](tutorials/write-a-skill-with-evals.md): write a small skill, prove it with evals, and lint it
- [Give a harness a tool](tutorials/give-a-harness-a-tool.md): add an MCP server and a blocking hook to a harness, against a fake Messages database

## How-to guides

Solve a specific task.

- [Add a skill to a plugin](how-to/add-a-skill-to-a-plugin.md)
- [Add a hook](how-to/add-a-hook.md)
- [Add a platform](how-to/add-a-platform.md): a read-only harness and platform skill for one tool
- [Add a triage question](how-to/add-a-triage-question.md): for the triage domain only
- [Run evals](how-to/run-evals.md)
- [Run SkillSpector](how-to/run-skillspector.md): the security scan CI runs

## Reference

Look up the facts.

- [Harness manifest](reference/harness-manifest.md): the fields of `.agents/harness/plugin.json` as this repo uses them
- [Skill layout](reference/skill-layout.md): directory, frontmatter, what `ynd lint` rejects, size limits

## Related reference elsewhere

- [Harnesses](../use/reference/harnesses.md): the harnesses in `ynh/`
- [ynh documentation](https://github.com/eyelock/ynh/blob/develop/docs/README.md), for the tools used here
- [agentskills.io specification](https://agentskills.io/specification)
