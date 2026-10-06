# Branch Protection Configuration

`main` is protected by one repository ruleset, "Main Branch Protection". There is no classic
branch protection: the ruleset is the single source of truth.

## Required check

One status check must pass before merging to `main`: **All Clear**. It is the last job of the
CI workflow, depends on every other job (build, test, lint, format check) and fails if any of
them failed or was cancelled. Add or rename CI jobs freely; only All Clear is required.

## Rules

- Changes reach `main` through a pull request
- All review conversations must be resolved
- The branch must be up to date with `main` before merging
- Force pushes blocked
- Branch deletion blocked
- Repository admins can bypass in emergencies
