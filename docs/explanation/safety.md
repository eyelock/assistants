# Safety

Every platform harness in this repo reads and never writes. This page explains how that is
enforced, why the enforcement differs between harnesses, and what is checked.

## Risk tiers

A tier says what an agent may do with a platform.

| Tier | The agent may | Approval |
|---|---|---|
| 0 | Read only | none needed, it cannot change anything |
| 1 | Prepare drafts, such as a reply or an event, that you send or save yourself | you send it |
| 2 | Act: send, change or delete | only after you approve each action |

Every harness in this repo is tier 0. Nothing here drafts or acts yet.

Tier 0 is a promise, so each harness needs a barrier that keeps it. The barrier differs by
server, and the sections below say how.

| Barrier | How it stops a write | Harnesses |
|---|---|---|
| The server | A read-only endpoint, a `--read-only` flag, or no write tool | `github`, `gmail`, `google-calendar`, `google-drive`, `imessage` |
| The credential | The token's scopes allow no write | `slack` |
| A hook | A `before_tool` hook in the harness blocks every write tool | `apple-calendar` |

The further down the table, the less the barrier is built into something you can inspect, and the
more the safety depends on one pattern in one file.

## Why a hook is the barrier for Apple Calendar

`che-ical-mcp`, the server behind `ynh/apple-calendar`, has no read-only mode. It registers 29
tools, 19 of which create, change or delete calendars, events and reminders. macOS offers
Calendar "Full Access" only as read and write, and reading events needs it. So neither the server
nor the permission can be narrowed.

The harness therefore blocks by name. Its `before_tool` hook matches every tool of that server
except six read tools. The matcher is a negative lookahead, so a tool not named is blocked, and
a tool added by a later server version is blocked too. The hook exits with code 2 and prints a
message telling the agent not to retry.

This is a deny-by-default list, but it is still one pattern. If the server renamed a read tool,
the harness would lose it; if the pattern were wrong, a writing tool would pass. That is why it
has its own test (`scripts/apple-calendar-guard.test.mjs` on that branch), which lists the
tools the server registers and checks each is blocked or allowed as intended.

## Why scopes for Slack

Slack's official server has no read-only switch. It exposes the tools the token's scopes allow.
With read scopes only it exposes eight read tools and nothing that posts. The barrier is the
token you create, which the harness cannot check. The harness documents the scopes to grant.

## Read only is not the same as private

`ynh/imessage` is read only: its server opens `chat.db` read-only and has no write tool. But the
model provider receives what tools return. By default the server runs with `--privacy full`, so
message text is sent. Profiles `redacted` and `counts` narrow that. Read-only protects the data,
not its disclosure.

## Untrusted content

Platform skills tell the agent to treat message and document text as data. An instruction found
in a message is reported, never followed. `.skillspector-baseline.yaml` records the places where
a skill quotes such an instruction as an example.

## What is verified

- `pnpm test` checks that every harness picks skills that exist, and that the common triage list
  and the harness focuses agree.
- Every new skill must have evals (`pnpm test` fails otherwise; older skills are listed in
  `scripts/skills-without-evals.txt`). Trigger and output evals use fixed fixtures and are run by hand
  ([Run evals](../how-to/run-evals.md)); CI does not run them.
- CI scans changed skills with SkillSpector.
- The Apple Calendar hook has a unit test on its branch.

## What is not verified

- That a server's read-only flag, endpoint or scope set really removes every write path. This is
  taken from each server's documentation, and the local servers are pinned to a version so a change is visible.
- That a hook matcher stops a real write against a real calendar. The test checks the pattern,
  not the running server.
- That a token was created with read scopes only.
- That an agent obeys the instruction-handling rules. The evals sample this; they do not prove it.
- Sensors: no harness declares any, so nothing observes the agent's output after it acts.
