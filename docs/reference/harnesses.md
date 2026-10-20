# Harnesses

One row per directory in `ynh/`, read from its `.agents/harness/plugin.json`. Tiers and barriers are
defined in [Safety](../explanation/safety.md).

## Platform harnesses

All answer the triage questions with the skills in `skills/triage`. Every one has `agent.max_turns` 25 and `agent.effort` `low`.

| Harness | Purpose | MCP server | Barrier | Profiles | Focuses |
|---|---|---|---|---|---|
| `github` | Reads GitHub: reviews, issues, notifications | `github`, `https://api.githubcopilot.com/mcp/readonly` | server | none | triage set, `all` |
| `gmail` | Reads Gmail | `gmail`, `uvx workspace-mcp@2.1.0 --read-only --tools gmail` | server | none | triage set, `all` |
| `google-calendar` | Reads Google Calendar | `google-calendar`, `uvx workspace-mcp@2.1.0 --read-only --tools calendar` | server | none | triage set without `my-commitments`, `all` |
| `google-drive` | Reads Drive, Docs, Sheets and Slides | `google-drive`, `uvx workspace-mcp@2.1.0 --read-only --tools drive docs sheets slides` | server | none | triage set, `all` |
| `imessage` | Reads Messages on a Mac | `imessage`, `npx imessage-mcp@3.2.0` | server | `redacted`, `counts` | triage set |
| `slack` | Reads Slack | `slack`, `https://mcp.slack.com/mcp` | credential | none | triage set, `all` |

The triage set is `waiting-on-me`, `waiting-on-them`, `action-now`, `action-soon`,
`my-commitments`, `catch-up` and `find`. See [Triage questions](triage-questions.md).

Credentials, passed through from the environment:

| Harness | Variables |
|---|---|
| `github` | `GITHUB_PERSONAL_ACCESS_TOKEN` |
| `gmail`, `google-calendar`, `google-drive` | `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `USER_GOOGLE_EMAIL` |
| `slack` | `SLACK_USER_TOKEN` |
| `imessage` | none; the host app needs Full Disk Access |

Profiles of `imessage`: the default runs `--privacy full`, `redacted` runs `--privacy redacted`
and `counts` runs `--privacy aggregate`.

### Not yet merged

`apple-calendar` exists on branch `feat/apple-calendar`, not on this one. It runs
`che-ical-mcp` (found on `PATH`), is read only through a hook, has no profiles, and its focuses are `waiting-on-me`,
`waiting-on-them`, `action-now`, `action-soon`, `catch-up`, `find` and `all`. Its `before_tool`
hook blocks every tool but six.

## Persona harnesses

These have no MCP server and no platform to protect. They compose skills from the shared library.

| Harness | Purpose | Profiles | Focuses |
|---|---|---|---|
| `david` | David's personal development persona | none | none |
| `planner` | Architecture and implementation planning | none | none |
| `researcher` | Research and analysis | none | none |
| `tester` | Testing and quality assurance | none | none |
| `termq-dev` | TermQ development, Gitflow with Swift and SwiftUI | `thorough`, `quick`, `security` | `code-review`, `security-audit`, `refactor`, `pr-summary`, `changelog` |
| `ynh-dev` | ynh development | `thorough`, `quick`, `security` | `code-review`, `security-hardening`, `cli-contract`, `refactor`, `changelog` |

No harness declares `hooks` or `sensors` on this branch.
