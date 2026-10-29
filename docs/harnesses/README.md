# Harnesses in depth

How a ynh harness works underneath, for any harness: the personas, the platform harnesses of
Triage, and the seats of a Wheelhouse. A harness is one file, `.agents/harness/plugin.json`, that
says which skills a session gets, which tools (MCP servers) it can call, and which checks (hooks)
run around it. ynh turns it into each vendor's native files.

## Tutorials

- [Follow a request](follow-a-request.md): open the real files to follow one request through a
  skill, a plugin, a harness, an MCP server and a hook. Read only, no model needed.
- [Give a harness a tool](give-a-harness-a-tool.md): add an MCP server and a blocking hook to a
  harness, against a fake Messages database.

## How-to guides

- [Add a hook](add-a-hook.md)

## Reference

- [Harness manifest](harness-manifest.md): the fields of `.agents/harness/plugin.json` as this
  repo uses them.

## Explanation

- [Vendors](vendors.md): how Claude Code, Cursor, Codex and Copilot CLI differ, and what could
  not be confirmed.
- [Safety](safety.md): how this repo handles risk, from risk tiers to hooks.

## Related

- [ynh documentation](https://github.com/eyelock/ynh/blob/develop/docs/README.md), for the tools
  used here.
