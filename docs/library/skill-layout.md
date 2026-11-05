# Skill layout

What a skill directory holds, which frontmatter it may carry, and what `ynd lint` rejects. The source is the [agentskills.io specification](https://agentskills.io/specification); ynh's notes are in [Agent Skills Standard](https://github.com/eyelock/ynh/blob/develop/docs/skills-standard.md).

## Where skills live

| Path | What it is |
|---|---|
| `skills/<domain>/skills/<name>/SKILL.md` | A skill in a shared skills package (`dev`, `voice`, `triage`, `platforms`, ...) |
| `plugins/<plugin>/skills/<name>/SKILL.md` | A skill in a plugin (`gitflow`, `media-management`, `vendor-harness`) |

## Directory

```
<name>/
├── SKILL.md          required: frontmatter and instructions
├── evals/            required in this repo
│   ├── evals.json
│   └── eval_queries.json
├── scripts/          optional: executable code
├── references/       optional: material loaded on demand
└── assets/           optional: templates and data
```

Scripts in this repo print JSON to stdout, diagnostics to stderr, accept `--help`, and use exit codes 0 (success), 1 (bad arguments), 2 (file not found) and 3 (tool error). They are idempotent, take no prompts, and run on macOS without bash 4 or GNU-only flags.

## Frontmatter

| Field | Status | Rule |
|---|---|---|
| `name` | required | 1 to 64 characters: lowercase letters, digits and hyphens. Must equal the directory name |
| `description` | required | 1 to 1024 characters. The only text the assistant sees until it opens the skill, so say what it does and when to use it |
| `allowed-tools` | optional | Space-delimited tools the skill may use without prompting (experimental in the spec) |
| Claude Code fields | optional | `disable-model-invocation`, `user-invocable`, `model`, `context`, `agent`, `argument-hint` |
| `compatibility` | rejected by `ynd lint` | In the spec. In a plugin it makes Claude Code demote the skill |
| `metadata` | rejected by `ynd lint` | Same |
| `license` | rejected by `ynd lint` | Same |

## What `ynd lint` rejects

A skill in a plugin that carries `compatibility`, `metadata` or `license` installs and never fires: Claude Code's plugin loader gives it about 10 tokens and leaves it out of the assistant's context, with no error anywhere else. Lint reports it:

```
skills/bad/SKILL.md:3: frontmatter "compatibility" is confirmed to cause demotion: Claude Code's plugin loader gives the skill ~10 tokens and excludes it from the agent's context, so it installs and never fires. Remove it, or keep this skill out of a plugin harness. See docs/skills-standard.md
```

Lint also reports a `name` that does not match its directory:

```
skills/bad/SKILL.md:1: frontmatter name "wrongname" does not match expected "bad"
```

Only top-level keys count, so a `metadata:` block with a `license:` under it is one finding. Lint also checks trailing whitespace, blank runs, final newlines, shell syntax in code blocks and manifest structure. `ynd validate` reports the same name mismatch, as `name "wrongname" does not match directory`.

The scaffold from `ynd create skill <name>` carries only `name` and `description`, so it passes.

## Size limits

| Limit | Value | Source | Checked by |
|---|---|---|---|
| `name` | 64 characters | spec | Not checked in v0.12.0 beyond the directory match |
| `description` | 1024 characters | spec | Not checked by `ynd lint` or `ynd validate` in v0.12.0 (a 1100-character description passed both) |
| `compatibility` | 500 characters | spec | Not applicable: lint rejects the field |
| `SKILL.md` body | under 500 lines, under about 5,000 tokens | spec and vendors' guidance | Not checked in v0.12.0 (a 600-line body passed both) |
| Skill catalog | about 2% of the context window across all skills | Claude Code | Keep descriptions short in large collections |

Past the body limit, move detail into `references/` and point to it from `SKILL.md`. The `skill-creator` skill in `skills/dev` pushes back on an oversized `SKILL.md`. `ynd compress` shortens verbose prompts.

## Evals

Every skill ships `evals/evals.json` and `evals/eval_queries.json`; `pnpm test` fails a new skill without them. Skills that predate the rule are listed in `scripts/skills-without-evals.txt`, which only shrinks. The formats are in [Write a skill with evals](write-a-skill-with-evals.md) and `AGENTS.md`; the options are in [Run evals](../testing/run-evals.md).
