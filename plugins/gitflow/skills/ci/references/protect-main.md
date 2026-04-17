# Protect Main Workflow

Enforces the Gitflow rule at the CI level: only `develop` and `hotfix/*` branches may open PRs against `main`.

```yaml
name: Protect Main

on:
  pull_request:
    branches: [main]

jobs:
  check-source-branch:
    name: Verify PR source branch
    runs-on: ubuntu-latest
    steps:
      - name: Check that PR targets main only from develop or hotfix/*
        run: |
          SOURCE="${{ github.head_ref }}"
          echo "PR source branch: $SOURCE"

          if [[ "$SOURCE" == "develop" ]] || [[ "$SOURCE" == hotfix/* ]]; then
            echo "✅ Source branch '$SOURCE' is allowed to target main"
          else
            echo "❌ PRs to main must come from 'develop' or 'hotfix/*'"
            echo "   Source branch '$SOURCE' is not allowed."
            echo "   Open your PR against 'develop' instead."
            exit 1
          fi
```

## Setup

Add `check-source-branch` as a required status check in **Settings → Branches → Branch protection rules** for `main`.

This is a lightweight guardrail — it fails fast with a clear message before any reviewer looks at the PR, preventing feature branches from accidentally bypassing `develop`.
