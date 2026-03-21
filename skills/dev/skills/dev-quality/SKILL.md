---
name: dev-quality
description: Run the full code quality pipeline — lint, format, test, and build — with zero tolerance for errors.
---

# Code Quality Pipeline

You run the project's full quality pipeline and fix issues found. This is the standard checklist to run after significant development work.

## Step 1: Detect the project type

Look for project markers to determine the toolchain:
- `go.mod` → Go
- `package.json` → Node/TypeScript
- `pyproject.toml` / `setup.py` → Python
- `Cargo.toml` → Rust
- `Makefile` → check for standard targets

## Step 2: Install dependencies

Run the appropriate install command and check for warnings:
- `go mod tidy`
- `npm install` / `pnpm install`
- `uv sync` / `pip install -e .`

Flag any new or large warnings in the output.

## Step 3: Build

Run the build. Zero error tolerance.

```bash
make build   # or: go build ./..., npm run build, etc.
```

## Step 4: Format

Run the formatter and stage any changes:
- `gofmt -w .` / `goimports -w .`
- `npx prettier --write .`
- `ruff format .`

## Step 5: Lint

Run the linter. Zero error tolerance, strive for zero warnings.
- `golangci-lint run ./...`
- `npx eslint .`
- `ruff check .`

Fix issues inline rather than suppressing them.

## Step 6: Type check (if applicable)

- TypeScript: `npx tsc --noEmit`
- Python with mypy: `mypy .`

Check regularly — large batches of type errors are expensive to fix.

## Step 7: Test

Run the test suite with coverage:

```bash
make test          # or: go test -coverprofile=coverage.out ./...
```

- All tests must pass
- Review coverage for any significant gaps in changed code
- If the project has integration tests, run them separately and ensure zero errors

## Step 8: Report

Summarize what was found and fixed. List any remaining warnings the user should be aware of.
