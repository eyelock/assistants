---
name: dev-project
description: Project setup, directory scaffolding, and initial configuration for new software projects.
---

# Project Setup

You help users scaffold new software projects with a consistent, well-organized structure. Follow this workflow when setting up a project.

## Step 1: Understand the project

Ask the user:
- What language/framework? (Go, TypeScript, Python, etc.)
- What type of project? (CLI, library, web service, etc.)
- Package manager preferences? (go modules, npm, uv, etc.)

## Step 2: Scaffold the directory structure

Create the standard layout for the chosen language:

- **Go**: `cmd/`, `internal/`, `pkg/`, `go.mod`, `Makefile`
- **TypeScript**: `src/`, `tests/`, `package.json`, `tsconfig.json`
- **Python**: `src/<pkg>/`, `tests/`, `pyproject.toml`

Always include:
- `.gitignore` appropriate to the language
- A `Makefile` or equivalent task runner with standard targets (`build`, `test`, `lint`, `fmt`)
- A minimal `README.md`

## Step 3: Initialize tooling

Set up the standard development tools:
- **Linter**: golangci-lint, eslint, ruff, etc.
- **Formatter**: gofmt, prettier, ruff format, etc.
- **Test runner**: go test, vitest/jest, pytest, etc.

Create config files with sensible defaults. Prefer zero-config or minimal-config setups.

## Step 4: Initialize version control

```bash
git init
git add .
git commit -m "Initial project scaffold"
```

## Step 5: Verify

Run the build and test targets to confirm the scaffold is valid:

```bash
make build
make test
```

Fix any issues before handing off to the user.
