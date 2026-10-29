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
(`~/.ynh`, `~/.claude/plugins`), so the run without the skill can't find and follow an installed
copy of it.

To write the evals this runs, see [Write a skill with evals](../tutorials/write-a-skill-with-evals.md).

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
