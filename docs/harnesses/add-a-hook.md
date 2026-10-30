# Add a hook

A hook is a script a vendor runs at a point in a session, such as before a tool call. Use one when an instruction is not enough and something must be refused, checked or logged every time. This page adds a `before_tool` hook that blocks a command, to a harness you own. For a first walk-through with a fake database, see [Give a harness a tool](give-a-harness-a-tool.md).

There are two places a hook can live in this repo. Pick by what you are building:

| You are building | Declare the hook in | Example |
|---|---|---|
| An ynh harness (`ynh/<name>`) | `hooks` in `.agents/harness/plugin.json` | `ynh/apple-calendar` |
| A Claude Code plugin (`plugins/<name>`) | `hooks/hooks.json` at the plugin root | `plugins/media-management/hooks/hooks.json` |

## In a harness

1. Write the script in the harness, for example `scripts/guard.sh`. The tool call arrives as JSON on stdin. Exit 2 blocks it, and what the script writes to stderr goes back to the model, so say what to do instead:

   ```bash
   #!/bin/bash
   # before_tool hook: block rm -rf. The tool call arrives as JSON on stdin.
   if ! command -v jq >/dev/null; then echo "BLOCKED: jq is required" >&2; exit 2; fi
   CMD=$(jq -r '.tool_input.command // empty')
   case "$CMD" in
     *"rm -rf"*) echo "BLOCKED: rm -rf is not allowed here. Remediation: delete the specific files you created, by name." >&2; exit 2 ;;
   esac
   exit 0
   ```

   A safety hook must not fail open: if `jq` is missing, block. `plugins/media-management/hooks/validate-bash-command.sh` does the same.

2. Make it executable and declare it. A command that starts with `./` names a script the harness ships; ynh copies it and rewrites the path.

   ```bash
   chmod +x scripts/guard.sh
   ```

   ```json
   "hooks": {
     "before_tool": [
       { "matcher": "Bash", "command": "./scripts/guard.sh" }
     ]
   }
   ```

   The events are `before_tool`, `after_tool`, `before_prompt`, `on_stop` (after every turn), `on_session_start` and, from ynh 0.14, `on_session_end` (best effort, with a short budget). `matcher` scopes a tool event to tool names (a pattern, not a glob), and an optional `timeout` gives the command that many seconds.

3. Test the script on its own, with the JSON a vendor would send:

   ```bash
   echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf build"}}' | scripts/guard.sh; echo "exit $?"
   echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | scripts/guard.sh; echo "exit $?"
   ```

   You should see:

   ```
   BLOCKED: rm -rf is not allowed here. Remediation: delete the specific files you created, by name.
   exit 2
   exit 0
   ```

4. Check that it assembles, and see how each vendor receives it:

   ```bash
   ynd validate .
   ynd lint .
   ynd preview . -v claude -o /tmp/hook-preview
   cat /tmp/hook-preview/.claude/hooks/hooks.json
   ```

   You should see Claude's `PreToolUse`, with the path reaching the copied script:

   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Bash",
           "hooks": [
             {
               "type": "command",
               "command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/guard.sh"
             }
           ]
         }
       ]
     }
   }
   ```

   `-v cursor` writes `.cursor/hooks.json` with `beforeShellExecution`. Copilot gets no hooks from ynh, so a hook that must hold cannot be your only barrier there.

5. Add a test in `scripts/` if the hook is the only thing standing between the model and a write. `scripts/apple-calendar-guard.test.mjs` checks a hook's `matcher` against every tool name of the server, so a tool added later cannot slip through.

## In a plugin

Write `hooks/hooks.json` at the plugin root in Claude Code's own format, and reach scripts with `${CLAUDE_PLUGIN_ROOT}`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/validate-bash-command.sh" }
        ]
      }
    ]
  }
}
```

That is `plugins/media-management/hooks/hooks.json`, trimmed. Claude Code loads `hooks/hooks.json` from a plugin without the manifest naming it. Other vendors do not read this file; the plugin's `.cursor-plugin/plugin.json` would need its own.

## More

- Events, per-vendor translation and script paths: [ynh Hooks](https://github.com/eyelock/ynh/blob/develop/docs/hooks.md)
- Per-profile hooks: a profile that declares `before_tool` replaces the default for that event only.
