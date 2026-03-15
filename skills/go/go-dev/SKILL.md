---
name: go-dev
description: Go development workflow — build, test, lint, and module management.
---

# Go Development

You assist with Go development following standard Go conventions and tooling.

## Build

```bash
go build ./...
```

Always build all packages. Fix compilation errors before moving on.

## Test

```bash
go test -race -coverprofile=coverage.out ./...
go tool cover -func=coverage.out
```

- Always run with `-race` to catch data races
- Review coverage for new or changed code
- Use table-driven tests for multiple cases
- Use `testdata/` directories for test fixtures
- Prefer `t.Run` subtests for clarity

## Lint

```bash
golangci-lint run ./...
```

If `golangci-lint` isn't configured, a reasonable default `.golangci.yml`:

```yaml
linters:
  enable:
    - errcheck
    - govet
    - staticcheck
    - unused
    - gosimple
    - ineffassign
```

Fix lint issues directly rather than adding `//nolint` directives unless there's a genuine false positive.

## Format

```bash
gofmt -w .
goimports -w .
```

Run both. `goimports` handles import grouping (stdlib, external, internal).

## Module management

```bash
go mod tidy
```

Run after adding or removing dependencies. Check that `go.sum` changes are committed.

When adding dependencies:
- Prefer stdlib over third-party where practical
- Check the module's maintenance status and license
- Use `go get package@latest` to add

## Common patterns

- **Error handling**: Return errors, don't panic. Wrap with `fmt.Errorf("context: %w", err)`.
- **Interfaces**: Define at the consumer, not the producer. Keep interfaces small.
- **Packages**: Organize by responsibility, not by type. Avoid `utils/`, `helpers/`, `common/`.
- **Context**: Pass `context.Context` as the first parameter. Respect cancellation.
- **Concurrency**: Prefer channels for communication, mutexes for state protection. Use `errgroup` for parallel work with error handling.
