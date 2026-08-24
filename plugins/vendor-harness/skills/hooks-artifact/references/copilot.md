# GitHub Copilot CLI — Hooks Reference

Docs: https://docs.github.com/en/copilot/reference/hooks-reference
      https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-hooks
      https://docs.github.com/en/copilot/concepts/agents/hooks

## Status

Generally available. Disable everything with `disableAllHooks: true` — either as a settings
key or inside a hooks file.

## Declaration Files

Loaded and **combined** from all of these — every matching entry from every source runs:

- Policy: `/etc/github-copilot/policy.d/*.json` (Linux/macOS),
  `C:\ProgramData\GitHub\Copilot\policy.d\*.json` (Windows) — alphabetical order, machine-wide
- Repository: `.github/hooks/*.json`
- User: `~/.copilot/hooks/*.json` (`%USERPROFILE%\.copilot\hooks\` on Windows)
- Inline: `hooks` key in `.github/copilot/settings.json` and `~/.copilot/settings.json`
- Plugin: `hooks.json` at plugin root, or `hooks/hooks.json` (or inline under `hooks` in
  `plugin.json`)

Copilot cloud agent reads **only** `.github/hooks/*.json`.

## Format — note the `version` field

```json
{
  "version": 1,
  "disableAllHooks": false,
  "hooks": {
    "preToolUse": [
      {
        "matcher": "bash",
        "type": "command",
        "bash": "./scripts/validate.sh",
        "powershell": "./scripts/validate.ps1",
        "timeoutSec": 30
      }
    ]
  }
}
```

`"version": 1` is required and has no counterpart in Claude, Cursor, or Codex. Copilot also
uses a **two-level** shape — event → array of hook objects — where Claude and Codex nest a
third level (`{matcher, hooks: [...]}`). Cursor's plugin format is two-level like Copilot but
uses different event names again.

## Hook Events (14)

camelCase, Copilot-native:

`sessionStart`, `sessionEnd`, `userPromptSubmitted`, `userPromptTransformed`, `preToolUse`,
`postToolUse`, `postToolUseFailure`, `permissionRequest`, `preCompact`, `agentStop`,
`subagentStart`, `subagentStop`, `errorOccurred`, `notification`

## Claude-Compatible PascalCase Aliases (12)

`SessionStart`, `SessionEnd`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`,
`PostToolUseFailure`, `PermissionRequest`, `PreCompact`, `Stop`, `SubagentStop`,
`ErrorOccurred`, `Notification`

Using the PascalCase name switches the payload to Claude's shape (ISO-8601 `timestamp`,
`tool_name`/`tool_input`, `initial_prompt`) **and** switches matcher semantics to
Claude-format. This is the compatibility seam — a Claude hooks file mostly works, but the
three-level `{matcher, hooks: [...]}` nesting does not.

`userPromptTransformed`, `subagentStart`, and `errorOccurred` have no PascalCase alias and no
Claude equivalent. `agentStop` maps to Claude's `Stop`.

## Hook Types (3)

| Type | Where |
|------|-------|
| `command` | all events |
| `http` | all events |
| `prompt` | **`sessionStart` only** |

`command` fields: `bash`, `powershell`, `command` (cross-platform fallback — at least one
required), `cwd`, `env`, `timeoutSec` (or `timeout`).

`http` fields: `url` (required), `headers`, `allowedEnvVars`, `timeoutSec`/`timeout`.
Sends the input payload as a JSON POST.

`prompt` fields: `prompt` — text or a slash command, auto-submitted.

No `agent` or `mcp_tool` type (Claude has both).

## Matchers

Compiled as `^(?:PATTERN)$` against a per-event field:

| Event | Matched field |
|-------|---------------|
| `preToolUse` / `PreToolUse` | `toolName` |
| `postToolUse` | `toolName` |
| `permissionRequest` | `toolName` |
| `preCompact` | `trigger` |
| `subagentStart` | `agentName` |
| `notification` | `notification_type` |

Claude-format matchers (used with PascalCase events) additionally accept `*`, `**`, empty
string, and `|`-separated alternation, and match Claude tool names — `Bash`, `Read`, `Write`,
`Edit`, `Grep`, `Glob`, `WebFetch`, `WebSearch`, `AskUserQuestion`, `TodoWrite`, `Agent`.

Copilot's own tool names for camelCase matchers: `ask_user`, `bash`, `create`, `edit`,
`glob`, `grep`, `powershell`, `task`, `view`, `web_fetch`, `web_search`, `rg`,
`str_replace_editor`, `apply_patch`, `update_todo`.

## Output Contracts

`preToolUse`:
```json
{"permissionDecision": "allow|deny|ask", "permissionDecisionReason": "...", "modifiedArgs": {}}
```

`permissionRequest`: `{"behavior": "allow|deny", "message": "...", "interrupt": true}`

`agentStop` / `subagentStop`: `{"decision": "block|allow", "reason": "...", "modifiedResponse": "..."}`
(`modifiedResponse` only on `subagentStop`)

`postToolUse`: `{"modifiedResult": {"resultType": "success", "textResultForLlm": "..."}, "additionalContext": "..."}`

`userPromptSubmitted`: `{"modifiedPrompt": "..."}`
`userPromptTransformed`: `{"modifiedTransformedPrompt": "..."}`
`notification`: `{"additionalContext": "..."}`

Progress can be streamed from a command hook before the final object:
```bash
echo '{"type": "progress", "message": "Checking policy..."}'
echo '{"permissionDecision": "allow"}'
```

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | success — stdout parsed as the hook output JSON |
| `2` | warning; on `preToolUse` / `permissionRequest` it means **deny**. stderr is surfaced |
| other non-zero | **fail-open** — except `preToolUse`, which is fail-closed |
| timeout | fail-open for **all** events, `preToolUse` included |

The timeout carve-out matters for security hooks: a hung `preToolUse` validator permits the
call. Keep `timeoutSec` tight and make the script fast.

## Execution

Hooks run on the developer's local machine in the same shell as the CLI. Entries from all
sources for the same event are combined and all run.

## Diagnostic Checklist

1. Is `"version": 1` present? Without it the file is not a valid hooks config.
2. Two-level shape? A three-level Claude-style `{matcher, hooks: [...]}` will not bind.
3. Event name spelled in one of the 14 camelCase or 12 PascalCase forms?
4. Matcher matching the right tool-name vocabulary for the casing you chose?
5. `prompt` type used on anything other than `sessionStart`? It will not fire.
6. Plugin hook edited in place? An installed plugin is a snapshot — reinstall it, or iterate
   with `copilot --plugin-dir ./my-plugin`, which reloads from the directory each run.
7. `disableAllHooks` set in settings or in a policy file higher up the chain?
