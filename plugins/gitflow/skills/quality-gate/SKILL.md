---
name: quality-gate
description: Four-gate quality model — build, lint, format, test — that must all pass before any commit.
---

# Quality Gate

All four gates must pass before any code is committed:

| Gate | What it checks | Requirement |
|---|---|---|
| Build | Compiles without errors | Zero errors, zero warnings |
| Lint | Static analysis | Zero violations — linter must exit 0 |
| Format | Code style consistency | Clean — run your formatter to fix |
| Tests | Automated test suite | All tests pass |

Run all four at once using your project's combined check target. For projects using Make:

```bash
make check
```

The output must be clean. Any `warning:` or `error:` lines in the output are failures.

Projects configure what each gate runs. The skill enforces the policy: zero tolerance on all four.

## Zero Tolerance

Never proceed to commit with build errors, lint errors, formatting violations, or failing tests.

If the check passes locally but CI fails, that is a bug — investigate and file an issue rather than pushing again.

## Verification Scope

Always run the full check command on a **clean build** before declaring the gate passed. Incremental compilation caches object files — repeat check runs will not regenerate warnings for already-compiled files. Only a clean build guarantees the full warning picture.

For Swift/Make projects:
```bash
swift package clean && make check
```

**Never declare success from an incremental build.** Test targets compile separately from the main target — warnings in test files only surface when tests are compiled.

## No Suppression Annotations

Do not add lint suppression annotations (e.g. `// swiftlint:disable`, `// nolint`, `#pragma warning disable`) to silence violations. Disabling rules file-wide or project-wide is also forbidden. Every violation must be fixed at the source.

## Line Length

When both a linter and a formatter enforce line length, they must be configured to the same limit. Neither tool auto-breaks long string literals — those require manual splitting. Do not disable line length rules; fix the code.

## Project Configuration

Each project defines its gate commands. Examples:

| Project type | Typical check target |
|---|---|
| Make-based | `make check` |
| Go | `go build ./... && golangci-lint run && gofmt -l . && go test ./...` |
| Node | `npm run build && npm run lint && npm run format:check && npm test` |
| Swift/Xcode | `make build && make lint && make format-check && make test` |

Document your project's gate commands in your CLAUDE.md or README so every contributor runs the same checks.
