# assistants

This is a reference repository of sample plugins, skills, and personas. It is not production software.

## Repository Structure

- `plugins/` — Self-contained plugins with manifests (`harness.json`, `.cursor-plugin/`)
- `skills/` — Shared skill plugins organized by domain, each with its own plugin manifests
- `ynh/` — Personas that compose skills from the shared library via includes
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

Every case that grants shell access runs under Claude Code's OS sandbox. Its commands can write only inside the run's directory and reach no network (they can still read files elsewhere, but cannot send them anywhere). Build caches live there too, so fixtures must need no downloads. See `plugins/gitflow/skills/push/evals/` for a worked example.

`pnpm test` fails when a new skill has no evals. Skills that predate the rule are listed in `scripts/skills-without-evals.txt`; that list only shrinks.

Run them with make:

- `make evals`: every skill's evals.
- `make eval P=<path>`: the evals of one skill, or of every skill in a package or plugin (`make eval P=plugins/gitflow`).
- Options for both: `MODE=output|triggers` (default: both), `RUNS=N` to repeat each output case, `MODEL=<model>` (default `sonnet`: scores stay comparable and runs stay cheap), `J=N` for concurrency, and `DRY_RUN=1` to list what would run.

Output evals run each case with and without the skill, graded by an LLM judge; trigger evals check the skill fires for the right requests. Results go to `.evals/<skill>-workspace/iteration-<N>/`, which is gitignored. For one suite with every option, use `node scripts/skill-evals.mjs <skill-dir> --help`. Runs use your own Claude Code login and cost money, so CI does not run them.

## Conventions

- Scripts output JSON to stdout, diagnostics to stderr
- Scripts accept `--help` for usage information
- Exit codes: 0 success, 1 bad args, 2 file not found, 3 tool error
- Scripts are idempotent and safe to re-run
- No interactive prompts — all input via arguments
- macOS compatible — no bash 4+ features, no GNU-only flags

## Working with this repo

- Do not modify skills content without understanding the agentskills.io spec
- Plugin manifests exist as `harness.json` and `.cursor-plugin/plugin.json` — keep them in sync
- Marketplace JSON files exist in three directories — keep them in sync (`pnpm sync-manifests` handles versions; `pnpm sync-manifests:check` gates CI)
- The Copilot index must avoid the `git-subdir`, `archive`, and `command` source types Claude allows — Copilot rejects the whole index over one unsupported entry
