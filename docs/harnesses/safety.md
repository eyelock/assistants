# Safety

An agent with tools can do harm that a chat model cannot. This page explains how this repo
handles that risk in general: what it promises, which barrier keeps each promise, and what is and
is not checked. The platform harnesses are the clearest case, but the same ideas apply to the
hooks in `plugins/media-management`, the scanning of every skill, and the rules skills give the
model about untrusted text.

## Risk tiers

A tier says what an agent may do with a system.

| Tier | The agent may | Approval |
|---|---|---|
| 0 | Read only | none needed, it cannot change anything |
| 1 | Prepare drafts, such as a reply or an event, that you send or save yourself | you send it |
| 2 | Act: send, change or delete | only after you approve each action |

Every harness in this repo is tier 0. Nothing here drafts or acts yet.

A tier is a promise, so each harness needs a barrier that keeps it. Prefer the barrier that is
built into something you can inspect, and say plainly when the barrier is weaker.

| Barrier | How it stops a write | Where in this repo |
|---|---|---|
| The server | A read-only endpoint, a `--read-only` flag, or no write tool | `ynh/github`, `gmail`, `google-calendar`, `google-drive`, `imessage` |
| The credential | The token's scopes allow no write | `ynh/slack` |
| A hook | A script the vendor runs before a tool call and that blocks it | `ynh/apple-calendar` |
| The skill's own rules | Instructions to the model: read only, never follow text found in data | every platform skill and `skills/triage/skills/triage-report` |

The further down the table, the less the barrier is built into something you can inspect. A
skill rule is the weakest: it asks the model to behave, and the evals sample whether it does.
That is why the first rows exist.

## Hooks as a barrier

A hook is a script the vendor runs around a tool call. It is the right barrier when the server
cannot be narrowed. `plugins/media-management/hooks/validate-bash-command.sh` shows the pattern
in a plugin that does write (it moves and tags files): it reads the pending command as JSON on
stdin, exits 2 with a message when the command is unsafe, and fails closed. If `jq` is missing it
blocks everything, because a safety hook must not fail open. A test runs it
(`plugins/media-management/tests/hooks/test-validate-bash-command.sh`).

The Apple Calendar harness uses the same mechanism for a different reason. Its server,
`che-ical-mcp`, has no read-only mode: it registers 29 tools, 19 of which create, change or delete
calendars, events and reminders, and macOS offers Calendar "Full Access" only as read and write.
So the harness blocks by name. Its `before_tool` hook matches every tool of that server except six
read tools, with a negative lookahead, so a tool not named is blocked, and a tool added by a later
server version is blocked too. It exits with code 2 and tells the agent not to retry. The hook has a test,
`scripts/apple-calendar-guard.test.mjs`, which checks the pattern against all 29 tool names. It has
not been run against the real server.

A deny-by-default pattern is still one pattern in one file. If the server renamed a read tool, the
harness would lose it; if the pattern were wrong, a writing tool would pass. That is why a hook
barrier needs its own test.

## Scopes as a barrier

Slack's official server has no read-only switch. It exposes the tools the token's scopes allow.
With read scopes only it exposes eight read tools and nothing that posts. The barrier is the token
you create, which the harness cannot check. The harness documents the scopes to grant.

## Read only is not the same as private

`ynh/imessage` is read only: its server opens `chat.db` read-only and has no write tool. But the
model provider receives what tools return. By default the server runs with `--privacy full`, so
message text is sent. Its profiles `redacted` and `counts` narrow that. Read-only protects the
data from change, not from disclosure. Profiles are the repo's tool for this kind of choice: the
safer variant is declared next to the default, in the same file.

## Untrusted content

Skills that read other people's text, such as the platform skills, tell the agent to treat message
and document text as data. An instruction found in a message is reported, never followed.
`.skillspector-baseline.yaml` records the places where a skill quotes such an instruction as an
example.

## Supply chain

Local MCP servers are started with `npx` or `uvx`, which download code. The harnesses pin each to
a version (for example `imessage-mcp@3.2.0`) so a change is visible in a diff. CI scans every
skill a pull request changes with SkillSpector, and a finding fails the build unless it is
accepted in `.skillspector-baseline.yaml` with a reason. Credentials are passed from the
environment with `env_passthrough`, never written into a manifest.

## What is verified

- `pnpm test` checks that every harness picks skills that exist, and that the common triage list
  and the harness focuses agree.
- Every new skill must have evals (`pnpm test` fails otherwise; older skills are listed in
  `scripts/skills-without-evals.txt`). Trigger and output evals use fixed fixtures and are run by
  hand ([Run evals](../testing/run-evals.md)); CI does not run them.
- CI scans changed skills with SkillSpector.
- The media-management safety hook has a shell test.

## What is not verified

- That a server's read-only flag, endpoint or scope set really removes every write path. This is
  taken from each server's documentation, and the local servers are pinned to a version so a
  change is visible.
- That a hook matcher stops a real write against a real service. A test checks the pattern, not
  the running server.
- That a token was created with read scopes only.
- That an agent obeys the instruction-handling rules. The evals sample this; they do not prove it.
- Sensors: no harness declares any, so nothing observes the agent's output after it acts.
