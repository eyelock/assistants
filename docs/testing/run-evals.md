# Run evals

Runs use your Claude Code login and cost money. List what would run first.

```bash
make eval P=skills/voice/skills/voice-warm DRY_RUN=1
```

One skill, or every skill in a package or plugin:

```bash
make eval P=skills/voice/skills/voice-warm
make eval P=plugins/gitflow
```

Every skill:

```bash
make evals DRY_RUN=1
make evals
```

Options for both targets:

| Option | Values | Default |
|---|---|---|
| `MODE` | `output`, `triggers`, `all` | `all` |
| `RUNS` | runs per output case | `1` |
| `MODEL` | model for the runs | `sonnet` |
| `J` | concurrency, 1 to 8 | `4` |
| `DRY_RUN` | `1` lists and runs nothing | off |

Only trigger evals, for one skill:

```bash
make eval P=skills/voice/skills/voice-warm MODE=triggers
```

One suite with every option:

```bash
node scripts/skill-evals.mjs skills/voice/skills/voice-warm --help
```

Results are in `.evals/<skill>-workspace/iteration-<N>/` (gitignored). CI does not run evals.

Each run has Claude Code's own memory off, and can't read skills installed on your machine
(`~/.ynh`, `~/.claude/plugins`). The run without the skill can't read this checkout either. So it
can't find a copy of the skill, installed or in the source, and follow it.

To write the evals this runs, see [Write a skill with evals](../library/write-a-skill-with-evals.md).

## Wake a seat through ynh

A case with `"seat": "<harness path>"` wakes a seat instead of a bare Claude session. The runner
launches `ynh run <seat> -v <vendor> -- -p ...` with a scratch `YNH_HOME` inside the run's
directory and `YNH_WORKSPACE_ROOTS` set to that directory. The seat's workspace folders are
granted with no `ynh trust accept`, and nothing reads or writes your real `~/.ynh`. The path is
relative to the run's directory (the case's `setup` lays the harness out there) or absolute.
It needs `ynh` installed.

```bash
make eval P=plugins/wheelhouse/skills/wake VENDOR=claude
node scripts/skill-evals.mjs plugins/wheelhouse/skills/wake --case seat-launch --no-baseline
```

The seat is what is under test, not a skill, so a seat case has one run, with no
without-skill control. `VENDOR=` (or `--vendor`) is passed to `ynh run -v` and defaults to `claude`.
Plain cases always run on Claude.

In a suite that mixes seat and plain cases, `run_summary.with_skill` and `without_skill` still average over every run of their arm, so they can cover different cases. `summary.delta` is computed only over the cases both arms ran, so a seat case never skews it.

The judge's view of the seat's tool calls is Claude-only. Only Claude's stream-json output is
parsed today. On another vendor the seat gets just the prompt, the judge sees the reply as plain
text, and `tool_calls` shows nothing, so a pass there rests on the stub log and the reply alone.
Each vendor's output is parsed in a later change.

## Run tutorials as tests

A tutorial can be a test too. One that opts in, with `<!-- tutorial: test sandbox=<path> -->` on
its first line, runs every `bash` block in order in a fresh temporary sandbox and fails on the
first that exits non-zero:

```bash
make test-tutorials
make test-tutorials T=docs/build/tutorials/build-a-wheelhouse.md
```

It needs the tools the tutorial uses and a network connection, and costs nothing: it checks that
every command still works, not what each one prints. A step after
`<!-- tutorial: skip unless VAR -->` runs only when `VAR` is set, such as `TUTORIAL_RUN_MODEL=1`
for a step that runs a model. A failure names the step and keeps its sandbox for you to look at.

A tutorial that teaches something from this repository can run against your checkout instead of
the published repository, so you can test changes before they are merged. Its marker names the
variable it reads the checkout's path from (`checkout=ASSISTANTS_CHECKOUT`), and the runner sets
it to the checkout it runs from. `TUTORIAL_PUBLISHED=1 make test-tutorials` runs it as a reader
would, against GitHub. By hand, set the variable yourself and follow the tutorial's "Developing
the plugin?" step.

To check the output against each "Expected" block too, have a model walk the tutorial. Paste
this into Claude Code, replacing the path:

```text
Read docs/build/tutorials/build-a-wheelhouse.md. Run every bash block in order, in this shell,
exactly as written; do not fix, skip or reorder anything unless the tutorial says a step may be
skipped. After each block compare what you see with the "Expected" text that follows it. Do not
edit any file. When you are done, list every step with: heading, ran (yes/no), matched
(yes/no/skipped), and for mismatches the observed output.
```

To write a tutorial both ways work with: one `bash` block per step, that pastes as it is, with no
placeholders, then the output to expect. Quote stable output exactly, and describe what changes
from run to run ("a 26-character id"). End with a clean-up step.

## When a case needs its own control

The run without the skill hides the plugin and this checkout. That is a fair control when the
behaviour being graded is written in the skill. It is no control when the behaviour is written in
something the case's own `setup` installs, such as a seat's charter from a template: that text is
in place in both runs, so both arms read it and test the same thing.

A case grading text its setup installs names its own control with `baseline_setup`, a script run
in place of `setup` in the `without_skill` arm. It installs the same fixtures minus the text under
test; the case's `expected_output` or the script's header says what it removes. For example, the
add-seat skill's reaping case sets `"baseline_setup": "../../evals/files/patrol-reap-control.sh"`,
which seats the CI watcher with its charter's Reaping section taken out.

Each run in `benchmark.json` carries a `control`: `null` for the run with the skill, and for the run
without it either `"plugin hidden"` (the default) or `"baseline_setup"`. Read a case's delta with
that in mind: a `baseline_setup` control that scores as high as the run with the skill means the
removed text was not what the behaviour depended on.

## Check calls before the judge

A case that records calls in the stub log (the default `gh` stub, or richer stubs its `setup`
installs) can fail on them with no model involved. Two fields hold call patterns, each a regular
expression matched against every line of the log, which reads `<command> <arguments>`:

- `forbidden`: patterns that fail the case outright. `"^gh pr merge"` fails the case if the seat
  merged; `"^git stash"` if it stashed.
- `required`: patterns that must each match some call. `"^git worktree add"` fails the case if the
  seat never made a worktree. Pair a must-not-act case with a twin that requires the safe call.

The plain checks run first. If any fails, the judge is not called: the run's `grading.json` has
`plain_check_failed: true`, each failed check names the call (`forbidden call made: gh pr merge 1`
or `no logged call matches`), and the case's `assertions` are reported as not graded. If they all
pass, the judge grades `assertions` as before, so keep those for the soft part: did the seat say
plainly what it did and why. Plain checks count in the pass rate like any assertion, in both arms.
