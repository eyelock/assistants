# Library

The skills and plugins in `skills/` and `plugins/`: development workflow, languages,
infrastructure, voice, pause, Gitflow, media and the vendor formats. Each follows the
[agentskills.io](https://agentskills.io/specification) format, so the same skill works in Claude
Code, Cursor, Codex and Copilot CLI. Install them as plugins, or let a harness compose them (see
[Personas](../personas/README.md)).

## Tutorials

- [Install a plugin](install-a-plugin.md): install `gitflow` into Claude Code.
- [Write a skill with evals](write-a-skill-with-evals.md): write a small skill, prove it with
  evals, and lint it.

## How-to guides

- [Install in Cursor and Copilot](install-in-cursor-and-copilot.md)
- [Add a skill to a plugin](add-a-skill-to-a-plugin.md)

## Reference

- [Skills](skills.md): every skill by domain.
- [Plugins](plugins.md): each plugin and package, and the tools that read it.
- [Skill layout](skill-layout.md): directory, frontmatter, what `ynd lint` rejects, size limits.

## Going further

Every skill ships with evals: see [Testing and CI](../testing/README.md).
