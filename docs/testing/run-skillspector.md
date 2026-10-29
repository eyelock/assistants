# Run SkillSpector

Needs Docker. This is the scan CI runs.

```bash
make skillspector
```

It runs this command, which you can also run directly:

```bash
docker run --rm -v "$PWD:/scan:ro" ghcr.io/eyelock/skillspector:1 gate . \
  --exclude '*/evals/files/*' --exclude 'e2e-fixtures/*'
```

To accept a false positive, add a rule to `.skillspector-baseline.yaml` with an `id`, a `path`
scoped to the file, and a `reason`. Read the finding first: if it is real, fix the skill.
