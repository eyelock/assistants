# Personas

A persona is one agent composed for a kind of work: a ynh harness in `ynh/<name>` that includes
skills from the [Library](../library/README.md), and may name profiles (variants of its
configuration) and focuses (ready-made prompts). It adds no MCP server and reaches no platform,
so it is the simplest harness. `ynh/david` is a personal development persona; `planner`,
`researcher`, `tester`, `termq-dev` and `ynh-dev` each suit one kind of work.

You need `ynh` and `ynd` v0.12.0, and Claude Code for the pages that run a model.

## Tutorials

- [Run a persona](run-a-persona.md): install and run the `planner` harness with `ynh`.
- [Build a persona harness](build-a-persona-harness.md): compose a code-review persona from
  existing skills with includes, a profile and a focus, and run it.

## Reference

- [Persona harnesses](harnesses.md): every persona, what it includes, and its profiles and
  focuses.

## Going further

How a harness works underneath (hooks, the manifest, the vendors) is in
[Harnesses in depth](../harnesses/README.md).
