# ynh E2E Fixtures

Hand-crafted, SHA-pinned harness fixtures consumed by the ynh E2E test suite
(see `eyelock/ynh` → `test/e2e/`). Each subdirectory is a complete, installable
harness exercising one shape of the ynh schema.

These fixtures are **not** production harnesses. They exist to give the ynh
test suite stable, byte-exact targets. The pinned SHAs live in
`eyelock/ynh:test/e2e/helpers.go`.

## Maintenance rule

When ynh's harness schema legitimately evolves, the same PR that changes the
schema must update the affected fixtures here and bump the SHA constants in
`eyelock/ynh:test/e2e/helpers.go`. CI on the schema PR runs the new fixtures,
so drift is caught immediately.

## Fixtures

| Fixture | Purpose |
|---------|---------|
| `minimal/` | Bare-minimum installable harness — name, version, description, default_vendor. No includes, delegates, hooks, or profiles. |

Additional fixtures (full-featured, with-delegates, with-floating-include,
with-pinned-include, with-tag-include, fork-source, invalid-schema) land
incrementally as the E2E suite grows; see the plan in
`eyelock/ynh:.claude/plans/e2e-test-suite.md`.
