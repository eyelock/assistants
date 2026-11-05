# Connect a platform

Give a read-only platform harness the credential or permission it needs. Each section is
independent: do only the platforms you use. Credentials come from your environment
(`env_passthrough` in the harness), so export them in the shell where you run `ynh run`.

None of these steps was run, because each needs an account of yours. Every variable name,
scope and server below is read from the harness manifest, its `AGENTS.md` or its platform skill.
Account-side clicking (creating a token or an OAuth client) is described only as far as the
repository says; follow the provider's own documentation for the rest.

## GitHub

The `github` harness sends `GITHUB_PERSONAL_ACCESS_TOKEN` as a bearer token to the read-only
endpoint `https://api.githubcopilot.com/mcp/readonly`.

1. Create a personal access token with read access only. Notifications need a personal access
   token with the `notifications` scope; an OAuth token from `gh auth token` lacks it, and the
   harness then reports that notifications could not be read and carries on with searches.
2. Export it:

   ```bash
   export GITHUB_PERSONAL_ACCESS_TOKEN=...
   ```

## Google (Gmail, Calendar, Drive)

`gmail`, `google-calendar` and `google-drive` run `uvx workspace-mcp@2.1.0 --single-user
--read-only`, each with its own `--tools` list. They need `uv` (for `uvx`) on your `PATH` and
three variables:

```bash
export GOOGLE_OAUTH_CLIENT_ID=...
export GOOGLE_OAUTH_CLIENT_SECRET=...
export USER_GOOGLE_EMAIL=you@example.com
```

The client id and secret are an OAuth client you create in your own Google Cloud project; the
server is [taylorwilsdon/google_workspace_mcp](https://github.com/taylorwilsdon/google_workspace_mcp)
and its documentation covers creating one. `--read-only` makes it request read scopes only and
remove the sending, drafting and labelling tools. The first run asks you to sign in to Google in a
browser (the standard flow for this server; not run here).

## Slack

The `slack` harness talks to Slack's official MCP server at `https://mcp.slack.com/mcp` with
`SLACK_USER_TOKEN`. The server has no read-only switch; it exposes only what the token's scopes
allow, so the scopes are the safety barrier.

1. Create a Slack app and enable its Slack MCP server access setting.
2. Grant these user scopes, and no write scope: `search:read`, `search:read.public`,
   `search:read.private`, `search:read.im`, `search:read.mpim`, `search:read.users`,
   `channels:history`, `groups:history`, `im:history`, `mpim:history`, `channels:read`,
   `groups:read`, `im:read`, `mpim:read`, `users:read`.
3. Install the app and copy the user token, which starts `xoxp-`. A bot token cannot search.
4. Export it:

   ```bash
   export SLACK_USER_TOKEN=xoxp-...
   ```

## iMessage

The `imessage` harness runs `npx -y imessage-mcp@3.2.0` and reads the Messages database on a Mac.
It needs no environment variable, but it needs `npx` (Node.js) and a macOS permission.

1. Open System Settings, Privacy and Security, Full Disk Access, and allow the app that launches
   the server (your terminal, or the editor you run `ynh` from). Without it the server cannot
   read `chat.db`.
2. Do not grant Automation for Messages. The harness never sends.
3. For a first trial, point the server at a copy of the database instead of the live one with
   its `--database <path>` option (from `skills/platforms/skills/imessage/references/tools.md`).
4. By default the model sees message text. For less, use `--profile redacted` (no text) or
   `--profile counts` (counts only); see
   [Ask a triage question](ask-a-triage-question.md).

## Apple Calendar

The server has not been run against a real calendar yet; the steps below come from its documentation and the harness.

1. Get the server, `che-ical-mcp` ([PsychQuant/che-ical-mcp](https://github.com/PsychQuant/che-ical-mcp)),
   a Swift binary. Pin one release, check its SHA-256 against the release, or build it from
   source with `swift build -c release`. Put it on your `PATH` as `che-ical-mcp`. Never use the
   server's built-in update option.
2. When macOS asks, allow Calendar and deny Reminders. macOS offers Calendar only as Full
   Access, which can write; a `before_tool` hook in the harness blocks every tool except six
   read tools.

## Check that it is connected

Install the harness and ask for something small, as in
[Ask a triage question](ask-a-triage-question.md). A missing credential shows up as the MCP
server failing to start or authenticate, and the harness cannot answer; fix the variable and run
again.
