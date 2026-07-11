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
| `with-floating-include/` | Harness with a single floating-ref include. Verifies SHA resolution and recording in `installed.json`. |
| `with-pinned-include/` | Harness with a SHA-pinned include. Verifies the resolved SHA matches the pin exactly. |
| `with-tag-include/` | Harness with a tag-pinned include (`e2e-fixtures-v1`). Verifies tag-to-SHA resolution. |
| `with-delegates/` | Harness with a delegate. Verifies delegate add/remove/update flows. |
| `fork-source/` | Harness designed to be forked. Verifies `forked_from` provenance recording and carry-forward. |
| `full-featured/` | Exercises a representative slice of manifest fields. Used by ls/info JSON envelope tests. |
| `invalid-schema/` | Deliberately broken — has an unknown top-level field. Verifies strict JSON parsing rejects it. |
| `included-skill/` | Stable include target referenced by the with-*-include fixtures and `with-delegates`. Not a harness — just a directory containing a `SKILL.md`. |
| `registry/index.json` | Test registry indexing the fixtures above. Used by `ynh search` and registry-source install tests. |

## Tags

| Tag | Purpose |
|-----|---------|
| `e2e-fixtures-v1` | Stable git tag pointing at the initial-fixture commit (`8713efa`). Used by `with-tag-include` to verify tag-to-SHA resolution. Move only with a coordinated ynh PR (the new commit's SHA replaces `AssistantsFixturesSHA` and the with-tag-include tag in `helpers.go`). |
