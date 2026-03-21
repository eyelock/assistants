---
name: go-lang
description: Go development workflow — Makefile-driven build, test, format, lint, and release with strict quality standards.
---

# Go Development

You assist with Go development. Always use Make targets rather than raw `go` commands — the Makefile is the single source of truth for build flags, tool versions, and pipeline order.

## Makefile as entry point

Every Go project should have a Makefile with these standard targets:

| Target | Purpose |
|--------|---------|
| `make build` | Build all binaries to `bin/` |
| `make test` | Run tests with `-race` and coverage |
| `make test-coverage` | Generate coverage profile with per-function report |
| `make format` | Run `goimports -w .` then `gofmt -s -w .` |
| `make lint` | Run `golangci-lint run ./...` |
| `make clean` | Remove build artifacts and caches |
| `make deps` | Install prerequisites (Go, golangci-lint, goimports) |
| `make check` | Full pipeline: deps, format, lint, test, build |
| `make install` | Build and install binaries to install directory |

Read the asset at `assets/Makefile` for the reference implementation.

`make check` is the local CI equivalent — run it before pushing.

## Build

```makefile
GOFLAGS := -v
VERSION := $(shell git describe --tags --always --dirty)

build:
	go build $(GOFLAGS) -ldflags "-X main.version=$(VERSION)" -o bin/<name> ./cmd/<name>
```

- Build to `bin/` directory, never in-place
- Inject version via `-ldflags` from git tags
- Use `-v` for visibility into what's being compiled
- `CGO_ENABLED=0` for release builds (cross-compilation, static binaries)

## Test

```bash
make test              # All tests with race detection + coverage
make test FILE=./internal/config  # Single package
```

Standards:
- Always run with `-race` to catch data races
- Coverage target: **90%+** on testable code
- Use `go tool cover -func=coverage.out` for per-function coverage reports

### Test patterns

- Standard `testing` package only — no test frameworks
- Table-driven tests for multiple scenarios
- Subtests via `t.Run()` for clarity
- `testdata/` directories for fixtures
- `t.TempDir()` for filesystem isolation
- `t.Setenv()` for environment variable overrides
- `t.Chdir()` for working directory changes
- Mock functions as replaceable package-level variables when needed

```go
func TestSomething(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    string
        wantErr bool
    }{
        {name: "valid input", input: "foo", want: "bar"},
        {name: "empty input", input: "", wantErr: true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := DoSomething(tt.input)
            if (err != nil) != tt.wantErr {
                t.Fatalf("DoSomething() error = %v, wantErr %v", err, tt.wantErr)
            }
            if got != tt.want {
                t.Errorf("DoSomething() = %q, want %q", got, tt.want)
            }
        })
    }
}
```

## Format

Order matters — run `goimports` first, then `gofmt`:

```bash
goimports -w .
gofmt -s -w .
```

- `goimports` handles import grouping (stdlib, external, internal) and removes unused imports
- `gofmt -s` simplifies code in addition to formatting

To check without modifying (CI mode):

```bash
goimports -l .   # List files that would change
gofmt -s -l .    # List files that would change
```

## Lint

```bash
golangci-lint run ./...
```

Read the asset at `assets/.golangci.yml` for the reference configuration. The default linter set:

- `errcheck` — all errors must be checked
- `govet` — go vet analysis
- `ineffassign` — unused variable assignments
- `staticcheck` — comprehensive static analysis
- `unused` — unused code detection

Exclude `testdata/` from linting.

Fix lint issues directly rather than adding `//nolint` directives unless there's a genuine false positive.

## Module management

```bash
go mod tidy
```

Run after adding or removing dependencies. Check that `go.sum` changes are committed.

Dependency principles:
- **Prefer stdlib** over third-party where practical — zero external dependencies is ideal
- Check the module's maintenance status and license before adding
- Use `go get package@latest` to add

## Project structure

```
project/
├── cmd/<name>/           # Binary entry points (main.go)
├── internal/             # Private packages
│   ├── config/           # Configuration and paths
│   ├── <domain>/         # Domain packages by responsibility
│   └── ...
├── testdata/             # Test fixtures (excluded from builds)
├── docs/                 # Documentation
├── bin/                  # Build output (gitignored)
├── Makefile
├── .golangci.yml
├── .goreleaser.yml       # Release config (if applicable)
├── go.mod
└── go.sum
```

- Organize packages by responsibility, not by type
- Avoid `utils/`, `helpers/`, `common/`
- Use `internal/` to prevent external imports of private packages
- Multiple binaries go in `cmd/<name>/` subdirectories

## Code patterns

- **Error handling**: Return errors, never panic. Wrap with context: `fmt.Errorf("loading config: %w", err)`
- **Interfaces**: Define at the consumer, not the producer. Keep them small.
- **Context**: Pass `context.Context` as the first parameter. Respect cancellation.
- **Concurrency**: Prefer channels for communication, mutexes for state protection. Use `errgroup` for parallel work with error handling.
- **CLI main**: Handle all error display in `main()` — internal packages return errors, they don't print.

## Release (goreleaser)

Read the asset at `assets/.goreleaser.yml` for the reference configuration.

Key settings:
- Pre-hooks: `go mod tidy` and `go test ./...` before building
- Cross-compile: darwin + linux, amd64 + arm64
- `CGO_ENABLED=0` for static binaries
- Ldflags: `-s -w` (strip debug info) plus version injection
- Archive format: `tar.gz` named `{project}_{version}_{os}_{arch}`
- Checksums file for verification
- Homebrew tap publishing (optional)

Tag a release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

CI triggers goreleaser on `v*` tags automatically.

## CI pipeline

The CI workflow should have separate jobs that map to Make targets:

1. **Build** — `make build`
2. **Test** — `make test`
3. **Lint** — `golangci/golangci-lint-action` (uses `.golangci.yml`)
4. **Format Check** — check `goimports -l .` and `gofmt -s -l .` output is empty
5. **All Clear** — aggregator job depending on all above (for branch protection rulesets)

Use the Go version from `go.mod` via `go-version-file: go.mod` in the setup-go action.

Skip jobs when only docs or non-code files change (path filtering).
