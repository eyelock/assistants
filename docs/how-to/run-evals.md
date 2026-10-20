# Run evals

Runs use your Claude Code login and cost money. List what would run first.

```bash
make eval P=skills/triage/skills/find DRY_RUN=1
```

One skill, or every skill in a package or plugin:

```bash
make eval P=skills/triage/skills/find
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
make eval P=skills/triage/skills/find MODE=triggers
```

One suite with every option:

```bash
node scripts/skill-evals.mjs skills/triage/skills/find --help
```

Results are in `.evals/<skill>-workspace/iteration-<N>/` (gitignored). CI does not run evals.
