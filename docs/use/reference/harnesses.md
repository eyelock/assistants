# Harnesses

One row per directory in `ynh/`, read from its `.agents/harness/plugin.json`. A harness is what
`ynh` installs and runs; see [Run a persona](../tutorials/run-a-persona.md) to use one. Tiers and
barriers are defined in [Safety](../../learn/explanation/safety.md).

There are two kinds. Personas compose skills for a kind of work. Platform harnesses add an MCP
server so the agent can read one platform.

## Persona harnesses

These have no MCP server and no platform to protect. They compose skills from the shared library
(`skills/` and `plugins/`) through `includes`. None sets `agent`, `env_passthrough` or
`mcp_servers`. Install one with `ynh install github.com/eyelock/assistants --path ynh/<name>`.

| Harness | Purpose | Includes | Profiles | Focuses |
|---|---|---|---|---|
| `david` | David's personal development persona | `dev-project`, `dev-quality`, `dev-review`, `dev-security`, `dev-backend`, `dev-ui`, `dev-debug`, `go-lang`, `gh-os-repo`, `terraform-backend-aws`, `help-me-answer`, `take-a-moment` | none | none |
| `planner` | Architecture and implementation planning | `dev-project`, `dev-review`, `gh-os-repo` | none | none |
| `researcher` | Research and analysis | `dev-review` | none | none |
| `tester` | Testing and quality assurance | `dev-quality`, `go-lang` | none | none |
| `termq-dev` | TermQ development, Gitflow with Swift and SwiftUI | the `gitflow` plugin, `dev-quality`, `dev-review`, `skill-creator`, `gh-cli`, `swift-lang` | `thorough`, `quick`, `security` | `code-review`, `security-audit`, `refactor`, `pr-summary`, `changelog` |
| `ynh-dev` | ynh development | the `gitflow` plugin, `golang-pro` from `github.com/Jeffallan/claude-skills`, `dev-quality`, `dev-review`, `skill-creator`, `gh-cli`, `go-lang`, the `pause` skills | `thorough`, `quick`, `security` | `code-review`, `security-hardening`, `cli-contract`, `refactor`, `changelog` |

`ynh-dev` is the only harness that includes something from outside this repository.
Only `apple-calendar` declares `hooks` (see below), and no harness declares `sensors`.

## Platform harnesses

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

### The Apple Calendar hook

`apple-calendar` is read only through a `before_tool` hook, because `che-ical-mcp` has no read-only mode and macOS Calendar access can write. The hook blocks every tool except `list_calendars`, `list_events`, `list_events_quick`, `search_events`, `check_conflicts` and `find_duplicate_events`. `scripts/apple-calendar-guard.test.mjs` tests the pattern against all 29 tool names. It has not been run against the real server.
