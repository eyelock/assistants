# Follow a request

In this tutorial you follow one request through the pieces of this repo by opening the files that
handle it. You will see a skill, a plugin, a harness and an MCP server, then run a hook by hand.
Nothing here calls a model, needs a login or changes anything. You need a checkout of this
repo, a shell, `jq` and Node.js 20 or later.

The request is: **"What is waiting on me on GitHub?"**

Start at the top of the checkout:

```bash
cd "$(git rev-parse --show-toplevel)"
```

## 1. The harness receives the request

A harness is the manifest that says what a session gets. The one for GitHub is `ynh/github`.

```bash
jq '{name, description, includes, env_passthrough}' ynh/github/.agents/harness/plugin.json
```

You should see three things. The `includes` list pulls two things from this repo: all of
`skills/triage`, and from `skills/platforms` only `skills/github`, through `pick`. The
`env_passthrough` list names the one environment variable the harness may pass on, a token. The
description ends in "Read-only."

Now see how a request becomes a prompt. The harness names a ready-made prompt, a focus, for each
question:

```bash
jq -r '.focuses["waiting-on-me"].prompt' ynh/github/.agents/harness/plugin.json
```

The prompt tells the model to use the `waiting-on-me` skill. Running `ynh run github --focus
waiting-on-me` would start a session with exactly that prompt. That command needs ynh and a token
and was not run for this tutorial.

## 2. The prompt names a skill

The skill is a directory with a `SKILL.md`.

```bash
ls skills/triage/skills/waiting-on-me
head -5 skills/triage/skills/waiting-on-me/SKILL.md
```

The first lines are frontmatter: a `name` and a `description`. The description is all a model sees
until it decides the skill fits; the body loads after that. Read the section "What counts" to see
what the skill treats as waiting on you:

```bash
sed -n '/^## What counts/,/^## How to look/p' skills/triage/skills/waiting-on-me/SKILL.md
```

This skill names no platform. It holds the question, not the place to look. The rules it shares
with the other triage skills are in a sibling skill:

```bash
grep -n "Read only" skills/triage/skills/triage-report/SKILL.md
```

## 3. A platform skill says where to look

The harness also picked the `github` skill. It knows GitHub, and it has a file that maps each
question to tools:

```bash
ls skills/platforms/skills/github/references
sed -n 1,8p skills/platforms/skills/github/references/triage.md
```

The `waiting-on-me` row names `search_pull_requests` with `review-requested:@me is:open`. Those
are tools of the MCP server in the next step. Skills and servers are separate: the skill knows
what to ask for, the server supplies the tools.

## 4. The harness declares the MCP server

```bash
jq '.mcp_servers' ynh/github/.agents/harness/plugin.json
```

The server is a remote URL, `https://api.githubcopilot.com/mcp/readonly`. The `readonly` in the
path is the barrier: this endpoint offers no tool that writes. The `Authorization` header holds
`${GITHUB_PERSONAL_ACCESS_TOKEN}`, a reference to your environment, not a secret in the file.
`X-MCP-Toolsets` lists the tool groups the harness asks for.

Compare with a harness that starts a local process instead:

```bash
jq '.mcp_servers' ynh/imessage/.agents/harness/plugin.json
```

Here the server is a command, `npx`, pinned to a version. The profiles in that file change one
flag on it:

```bash
jq -r '.profiles | to_entries[] | "\(.key): \(.value.mcp_servers.imessage.args | join(" "))"' ynh/imessage/.agents/harness/plugin.json
```

## 5. The plugin makes the skills installable

The harness pulled skills from `skills/triage`. That directory is also a plugin that a vendor tool
can install without ynh, because it carries a manifest:

```bash
ls -a skills/triage
jq . skills/triage/.claude-plugin/plugin.json
```

A plugin is the same skills plus manifests: `.claude-plugin/plugin.json` for Claude Code,
`.cursor-plugin/plugin.json` for Cursor and `.agents/harness/plugin.json` for ynh. See which
marketplace lists it:

```bash
jq -r '.plugins[].name' .claude-plugin/marketplace.json
```

## 6. Check that the pieces agree

The repo checks that every harness picks skills that exist:

```bash
node --test scripts/harness-picks.test.mjs
```

Every test should pass. Rename a picked skill in a scratch copy and the matching test would fail,
which is how a broken `pick` is caught before someone installs the harness.

## 7. Where a hook would sit

The GitHub harness has no hook, because the read-only endpoint is the barrier. A hook is for
when no such endpoint exists. This repo's working hooks are in `plugins/media-management`:

```bash
jq '.hooks | keys' plugins/media-management/hooks/hooks.json
jq '.hooks.PreToolUse[0]' plugins/media-management/hooks/hooks.json
```

The first `PreToolUse` entry runs `validate-bash-command.sh` before every `Bash` tool call. The
vendor sends the pending call to the script as JSON. Send it one by hand. First a command the hook
blocks:

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"unzip a.zip -d ~/Downloads/"}}' \
  | bash plugins/media-management/hooks/validate-bash-command.sh
echo "exit code: $?"
```

It prints `BLOCKED: Cannot extract directly to Downloads root...` and exits with 2, which tells
the vendor to stop the call and show the message to the model. Now one it allows:

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' \
  | bash plugins/media-management/hooks/validate-bash-command.sh
echo "exit code: $?"
```

It prints nothing and exits with 0: the hook has no objection, and the normal permission flow
continues. The script needs `jq`; without it, it blocks everything on purpose.

## What you saw

| Step | Piece | File |
|---|---|---|
| 1 | harness and focus | `ynh/github/.agents/harness/plugin.json` |
| 2 | generic skill | `skills/triage/skills/waiting-on-me/SKILL.md` |
| 3 | platform skill | `skills/platforms/skills/github/references/triage.md` |
| 4 | MCP server | the `mcp_servers` key of the harness |
| 5 | plugin and marketplace | `skills/triage/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` |
| 6 | the repo's own check | `scripts/harness-picks.test.mjs` |
| 7 | hook | `plugins/media-management/hooks/validate-bash-command.sh` |

The request passed through a skill, a harness and an MCP server, but not a hook. That is the
point of the last step: which controls a request meets depends on what the harness declares.

## Next

- [Agentic features](../explanation/agentic-features.md): what each piece is, and why.
- [Architecture](../explanation/architecture.md): how the pieces layer.
- [Safety](../explanation/safety.md): why GitHub uses an endpoint and media uses a hook.
- To make your own, see the build track: [Give a harness a tool](../../build/tutorials/give-a-harness-a-tool.md).
