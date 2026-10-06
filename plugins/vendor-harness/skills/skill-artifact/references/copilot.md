# GitHub Copilot CLI — Skill Artifact Reference

Docs: https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills
      https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference

## Skill Location

Plugin skills: `skills/<name>/SKILL.md` at plugin root (override with the `skills` field in
`plugin.json`; accepts a string or an array of paths)

Project skills (all three are read):
- `.github/skills/<name>/SKILL.md`
- `.claude/skills/<name>/SKILL.md`   ← Claude Code project skills load in Copilot unchanged
- `.agents/skills/<name>/SKILL.md`

Personal skills:
- `~/.copilot/skills/<name>/SKILL.md`
- `~/.agents/skills/<name>/SKILL.md`

Extra directories can be added with the `skillDirectories` setting, or `/skills add`.

Directory names must be lowercase and hyphen-separated, and the file must be named
exactly `SKILL.md`.

## Frontmatter

Required: `name` (lowercase, hyphenated, must match the directory name), `description`.
Optional: `license`, `allowed-tools`.

No character limits are documented for `name` or `description`.

`allowed-tools` pre-approves tool execution for the skill. GitHub's own docs carry a
warning: pre-approving `shell`/`bash` removes the confirmation step and lets an
attacker-controlled skill run arbitrary commands. Treat it as a security decision, not a
convenience.

Claude Code extensions (`disable-model-invocation`, `user-invocable`, `model`, `context`,
`agent`, `argument-hint`) are not documented for Copilot CLI skills. VS Code's Copilot does
document `disable-model-invocation`, `user-invocable`, `argument-hint` and `context`, but that
is not a promise for the CLI: a skill that must never run on its own needs a guard that does
not depend on the field. Agent-level equivalents live in `.agent.md` custom agents.

## Invocation

`/skill-name` — explicit invocation
Automatic activation is driven by the `description`, same as every other vendor.

Session commands: `/skills list`, `/skills info`, `/skills reload`, `/skills add`,
`/skills remove`.

`/skills reload` refreshes skills mid-session — but only for skill directories, not for
plugin-installed skills, which are cached at install time.

## Precedence and Deduplication

Skills dedupe by the `name` frontmatter field, first-found-wins in this order:

1. Built-in (cannot be overridden)
2. User — `~/.copilot/skills/`
3. Project — `.github/skills/`, `.claude/skills/`, `.agents/skills/`
4. Inherited — monorepo parent directories
5. Plugin — in install order
6. Remote organization / enterprise

A project skill silently shadows a plugin skill of the same name — no warning is emitted.
This is the first thing to check when a plugin skill "isn't loading".

Skills can be switched off individually with the `disabledSkills` setting.

## Known Gaps and Quirks

- No metadata demotion bug — the Claude Code `metadata`/`compatibility`/`license` problem
  does not apply here, and `license` is in fact a documented optional field. A skill written
  to be Claude-safe is automatically Copilot-safe; the reverse is not true.
- An *installed* plugin is a snapshot in `~/.copilot/installed-plugins/`. After editing a
  plugin skill, reinstall it — `/skills reload` will not pick it up. Better: iterate with
  `copilot --plugin-dir ./my-plugin`, which loads from the directory each run.
- Scripts inside a skill directory are auto-discovered.
- No documented context budget for the skill catalog (contrast Claude's 2% reservation).
