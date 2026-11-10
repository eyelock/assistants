# assistants

This is a reference repository of sample plugins, skills, and personas. It is not production software.

## Repository Structure

- `plugins/` — Self-contained plugins with manifests (`.agents/harness/plugin.json`, `.claude-plugin/`, `.cursor-plugin/`)
- `skills/` — Shared skill plugins organized by domain, each with its own plugin manifests
- `ynh/` — ynh harnesses: personas that compose skills, and read-only platform harnesses that add an MCP server
- `docs/` — The docs, one folder per area (`start/`, `library/`, `personas/`, `harnesses/`, `testing/`, `triage/`, `wheelhouse/`); inside each, pages are tutorials, how-to guides, reference or explanation, as on diataxis.fr. Every link must resolve (`pnpm test` checks). View them with `make docs` (http://localhost:3000)
- `.claude-plugin/marketplace.json` — Claude Code marketplace index
- `.cursor-plugin/marketplace.json` — Cursor marketplace index
- `.github/plugin/marketplace.json` — GitHub Copilot CLI marketplace index

## Skills

All skills follow the [agentskills.io specification](https://agentskills.io/specification). Each skill is a directory containing a `SKILL.md` file with YAML frontmatter (`name`, `description`) followed by Markdown instructions. Skills may include `scripts/`, `references/`, and `assets/` subdirectories.

Skills live under `skills/<domain>/skills/<skill-name>/SKILL.md`.

## Evals

Every skill ships with evals, in the [agentskills.io format](https://agentskills.io/skill-creation/evaluating-skills):

- `evals/evals.json`: output evals. Each case has a realistic `prompt`, an `expected_output`, the `files` it needs and `assertions` a grader can check from the output alone.
- `evals/eval_queries.json`: trigger evals. Queries marked `should_trigger`, with near misses that must not trigger.

Fixtures are fixed snapshots, never live accounts, so a case passes or fails for the same reason every time. A package keeps shared fixtures in its own `evals/files/`.

A skill that runs commands gets a **sandboxed case**, an extension to the spec's case format:

- `setup`: a script, relative to the skill, that builds the case's world in the run's directory. Examples: a git repo whose `origin` is a local bare repository, or real audio files made with ffmpeg. It gets `$EVAL_FIXTURES` (the package's `evals/files/`), and `$EVAL_BIN` for realistic stub commands, which log to `$EVAL_STUB_LOG`.
- `tools`: extra tools, such as `"Edit(./**)"`. Any `Bash` entry means shell access, and both arms get the same unrestricted shell: the OS sandbox below is the boundary, since a command allow-list breaks as soon as a model phrases a command differently.
- `stubs`: commands replaced by recorders, such as `gh` (the default once any shell access is granted). Nothing reaches a real service.
- `evidence`: a command run afterwards, for example `git log --all` or `find . -type f`. Its output and the stub calls go to the judge, so assertions can check what was actually done.
- `tool_calls`: tools whose calls the judge sees, with their input, which must be granted in `tools` too. Not every tool loads in an eval session: `AskUserQuestion` does not (see [assistants #133](https://github.com/eyelock/assistants/issues/133)), so a case about how the agent asks checks the plain-text fallback instead.

Every case that grants shell access runs under Claude Code's OS sandbox. Its commands can write only inside the run's directory and reach no network (they can still read most files elsewhere, but cannot send them anywhere). Build caches live there too, so fixtures must need no downloads.

Every run, with or without the skill, has Claude Code's own memory off and cannot read the copies of skills installed on the machine (`~/.ynh`, `~/.claude/plugins`). The run without the skill cannot read this checkout either, where the skill's source is. Otherwise a baseline can find the skill under test and follow it, and a "remember this" goes to the harness's memory rather than the skill. A case never needs the checkout: runs work in a temporary directory, and the runner gathers the evidence. See `plugins/gitflow/skills/push/evals/` for a worked example.

`pnpm test` fails when a new skill has no evals. Skills that predate the rule are listed in `scripts/skills-without-evals.txt`; that list only shrinks.

Run them with make:

- `make evals`: every skill's evals.
- `make eval P=<path>`: the evals of one skill, or of every skill in a package or plugin (`make eval P=plugins/gitflow`).
- Options for both: `MODE=output|triggers` (default: both), `RUNS=N` to repeat each output case, `MODEL=<model>` (default `sonnet`: scores stay comparable and runs stay cheap), `J=N` for concurrency, and `DRY_RUN=1` to list what would run.

Output evals run each case with and without the skill, graded by an LLM judge; trigger evals check the skill fires for the right requests. Results go to `.evals/<skill>-workspace/iteration-<N>/`, which is gitignored. For one suite with every option, use `node scripts/skill-evals.mjs <skill-dir> --help`. Runs use your own Claude Code login and cost money, so CI does not run them.

## Triage questions

The common triage questions (what is waiting on me, what I am waiting on, what to act on now or
soon, what I promised, catch up, find) are one list that every platform harness answers the same
way. Before adding a question, or a platform-specific feature that looks like one, read the
`add-triage-question` skill (`skills/triage/skills/add-triage-question`): most ideas should stay
off the list. `pnpm test` fails when a harness and the list disagree.

## Security scan

CI scans every skill a pull request changes with [NVIDIA SkillSpector](https://github.com/NVIDIA/SkillSpector),
through [`eyelock/actions/skillspector`](https://github.com/eyelock/actions/tree/develop/skillspector).
Any finding not accepted in `.skillspector-baseline.yaml` fails the build.

When it flags something, read the finding first. If it is a real concern, fix the skill: pin
what a harness downloads, and don't hand the agent pipe-to-shell commands. If it is a false
positive, add a rule to the baseline with an `id`, a `path` scoped to the file, and a `reason`.
Run it locally with `make skillspector` (needs Docker), which runs:

```bash
docker run --rm -v "$PWD:/scan:ro" ghcr.io/eyelock/skillspector:1 gate . \
  --exclude '*/evals/files/*' --exclude 'e2e-fixtures/*'
```

## Conventions

- Scripts output JSON to stdout, diagnostics to stderr
- Scripts accept `--help` for usage information
- Exit codes: 0 success, 1 bad args, 2 file not found, 3 tool error
- Scripts are idempotent and safe to re-run
- No interactive prompts — all input via arguments
- macOS compatible — no bash 4+ features, no GNU-only flags

## Merge queue

`develop` and `main` are meant to be protected by a merge queue: a pull request merges only after All
Clear passes on the branch as it will be with the queued pull requests ahead of it merged, so two pull
requests that are each green cannot combine red. `develop` queues as squash; `main` queues as a merge
commit. GitHub offers merge queues to organization-owned repositories, so a personal-account repository
like this one may be refused; the fallback is strict required status checks.

What protects each branch depends on how far the admin step got (it has three stages):

- Before stage 2 finishes for a branch: the classic rule, requiring `Check`, with admins enforced.
- After stage 2, with stage 3 not run or refused: the branch's ruleset (All Clear, a pull request,
  no deletion, no force push), and no queue. Pull requests merge one at a time, as before.
- After stage 3: the ruleset and the merge queue.

The rulesets' bypass list holds the repository admin role in `"bypass_mode": "pull_request"`, not
`"always"`. Every seat pushes under the admin account, and classic protection refuses even an admin's
direct push (`enforce_admins`); `"always"` would let a seat's direct push to `develop` or `main` land.
`pull_request` lets the admin bypass the rules only on a pull request, which is all the release
back-merge below needs, and a direct push is still refused.
`ci.yml` triggers on `merge_group` and every job in it runs there. Any new required check must also
trigger on `merge_group`, and must never be skipped by a path filter or by a missing head ref in the queue.

Cutting a release: the `release/YYYY-MM-DD` pull request into `main` and the `changeset-release/main`
Version Packages pull request go through the queue. The back-merge of `main` into `develop` after a
release is the exception: it must land as a merge commit, which the `develop` queue (squash) cannot do,
so an admin merges that pull request directly with a merge commit, around the queue:
`gh pr merge <number> --repo eyelock/assistants --merge --admin`.

## Working with this repo

- Do not modify skills content without understanding the agentskills.io spec
- Plugin manifests exist as `.agents/harness/plugin.json` and `.cursor-plugin/plugin.json` — keep them in sync
- Marketplace JSON files exist in three directories — keep them in sync (`pnpm sync-manifests` handles versions; `pnpm sync-manifests:check` gates CI)
- The Copilot index must avoid the `git-subdir`, `archive`, and `command` source types Claude allows — Copilot rejects the whole index over one unsupported entry
