---
name: quality-gate
description: Four-gate quality model — build, lint, format, test — that must all pass before any commit.
---

# Quality Gate

All four gates must pass before any code is committed:

| Gate | What it checks | Requirement |
|---|---|---|
| Build | Compiles without errors | Zero errors |
| Lint | Static analysis | Zero errors (minimize warnings) |
| Format | Code style consistency | Clean — run your formatter to fix |
| Tests | Automated test suite | All tests pass |

Run all four at once using your project's combined check target. For projects using Make:

```bash
make check
```

Projects configure what each gate runs. The skill enforces the policy: zero tolerance on all four.

## Zero Tolerance

Never proceed to commit with build errors, lint errors, formatting violations, or failing tests.

If the check passes locally but CI fails, that is a bug — investigate and file an issue rather than pushing again.

## Project Configuration

Each project defines its gate commands. Examples:

| Project type | Typical check target |
|---|---|
| Make-based | `make check` |
| Go | `go build ./... && golangci-lint run && gofmt -l . && go test ./...` |
| Node | `npm run build && npm run lint && npm run format:check && npm test` |
| Swift/Xcode | `make build && make lint && make format-check && make test` |

Document your project's gate commands in your CLAUDE.md or README so every contributor runs the same checks.
