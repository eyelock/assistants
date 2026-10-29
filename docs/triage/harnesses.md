# Platform harnesses

One row per platform harness in `ynh/`, read from its `.agents/harness/plugin.json`. Each adds
one MCP server so the agent can read one platform, and is read only. Tiers and barriers are
defined in [Safety](../harnesses/safety.md); the personas are in
[Persona harnesses](../personas/harnesses.md).

All answer the triage questions with the skills in `skills/triage`. Every one has `agent.effort` `low` and `agent.max_turns` 25, except `slack`, which has 40.

| Harness | Purpose | MCP server | Barrier | Profiles | Focuses |
|---|---|---|---|---|---|
| `github` | Reads GitHub: reviews, issues, notifications | `github`, `https://api.githubcopilot.com/mcp/readonly` | server | none | triage set, `all` |
| `gmail` | Reads Gmail | `gmail`, `uvx workspace-mcp@2.1.0 --read-only --tools gmail` | server | none | triage set, `all` |
| `google-calendar` | Reads Google Calendar | `google-calendar`, `uvx workspace-mcp@2.1.0 --read-only --tools calendar` | server | none | triage set without `my-commitments`, `all` |
| `google-drive` | Reads Drive, Docs, Sheets and Slides | `google-drive`, `uvx workspace-mcp@2.1.0 --read-only --tools drive docs sheets slides` | server | none | triage set, `all` |
| `imessage` | Reads Messages on a Mac | `imessage`, `npx imessage-mcp@3.2.0` | server | `redacted`, `counts` | triage set |
| `apple-calendar` | Reads Apple Calendar on a Mac | `apple-calendar`, `che-ical-mcp` (on `PATH`) | hook | none | triage set without `my-commitments`, `all` |
| `slack` | Reads Slack | `slack`, `https://mcp.slack.com/mcp` | credential | none | triage set, `all` |

The triage set is `waiting-on-me`, `waiting-on-them`, `action-now`, `action-soon`,
`my-commitments`, `catch-up` and `find`. See [Triage questions](../triage/triage-questions.md).

Credentials, passed through from the environment:

| Harness | Variables |
|---|---|
| `github` | `GITHUB_PERSONAL_ACCESS_TOKEN` |
| `gmail`, `google-calendar`, `google-drive` | `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `USER_GOOGLE_EMAIL` |
| `slack` | `SLACK_USER_TOKEN` |
| `imessage` | none; the host app needs Full Disk Access |

Profiles of `imessage`: the default runs `--privacy full`, `redacted` runs `--privacy redacted`
and `counts` runs `--privacy aggregate`.

## The Apple Calendar hook

`apple-calendar` is read only through a `before_tool` hook, because `che-ical-mcp` has no read-only mode and macOS Calendar access can write. The hook blocks every tool except `list_calendars`, `list_events`, `list_events_quick`, `search_events`, `check_conflicts` and `find_duplicate_events`. `scripts/apple-calendar-guard.test.mjs` tests the pattern against all 29 tool names. It has not been run against the real server.

Only `apple-calendar` declares `hooks`, and no harness declares `sensors`.
