# CI Workflow

Runs on every push to `main`, `develop`, and `hotfix/*`, and on every PR targeting those branches.

## Key Patterns

**Paths filter** — skip expensive jobs when only docs or configs changed:

```yaml
- uses: dorny/paths-filter@v4
  id: filter
  with:
    filters: |
      code:
        - 'src/**'
        - 'Makefile'
        - '.github/workflows/**'
```

**Separate jobs per gate** — build, test, lint, format run in parallel, each conditional on `needs.changes.outputs.code == 'true'`.

**All Clear aggregator** — the only job branch protection requires. Always runs (`if: always()`), checks `contains(needs.*.result, 'failure')`:

```yaml
all-clear:
  name: All Clear
  runs-on: ubuntu-latest
  needs: [changes, build, test, lint, format]
  if: always()
  steps:
    - name: Check results
      run: |
        if [[ "${{ contains(needs.*.result, 'failure') }}" == "true" ]] || \
           [[ "${{ contains(needs.*.result, 'cancelled') }}" == "true" ]]; then
          echo "❌ One or more checks failed"
          exit 1
        fi
        echo "✅ All checks passed or skipped appropriately"
```

Why an aggregator? When jobs are skipped (paths filter), GitHub marks them as "skipped" not "passed". A required check that is skipped blocks the PR. The aggregator treats "skipped" as passing and gives branch protection a single stable check to require.

## Trigger Configuration

```yaml
on:
  push:
    branches: [main, develop, 'hotfix/*']
  pull_request:
    branches: [main, develop]
  workflow_dispatch:
```

`workflow_dispatch` lets you re-run CI manually without a commit.

## Adapting to Your Stack

Replace `make build`, `make test`, `make lint`, `make format-check` with your project's gate commands. The structure (separate jobs + aggregator) is language-agnostic.
