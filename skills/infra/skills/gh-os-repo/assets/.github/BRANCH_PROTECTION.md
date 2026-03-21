# Branch Protection Configuration

## Main Branch Required Checks

The following CI checks must pass before merging to `main`:

- **Build**: Verify code compiles successfully
- **Test**: Run all unit tests
- **Lint**: Code quality checks
- **Format Check**: Code style verification

All checks are configured to run via GitHub Actions on every pull request.

## Configuration

Branch protection is configured via GitHub API and applies to the `main` branch.

Settings:
- Required status checks must pass (strict — branch must be up to date)
- All review conversations must be resolved
- Force pushes blocked
- Branch deletion blocked
- Admins can bypass in emergencies

## Rulesets

A "Main Branch Protection" ruleset provides defense-in-depth:
- Blocks non-fast-forward pushes
- Blocks branch deletion
- Requires "All Clear" status check (aggregates all CI jobs)
