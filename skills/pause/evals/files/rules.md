# Project rules

## Testing and dependencies

- **ALWAYS use Makefile targets.** Never run `go test`, `go build` or `golangci-lint` directly. `make test` sets the race detector, build tags and the test database URL; running `go test` yourself skips all three.
- Run `make check` before saying a change is done.
