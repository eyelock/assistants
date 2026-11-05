#!/usr/bin/env bash
# Builds the gh-os-repo sandbox in the current directory: a checkout of
# acme/widget, a small Go project about to go public, whose CI runs build,
# test, lint and format-check jobs and an All Clear job that needs them but has
# no if: always() (so it is skipped, not failed, when one fails), and a gh
# (gh-os-repo-stub.sh) that answers like GitHub for it and records every call.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail

git init -q -b main .
echo ".eval/" >>.git/info/exclude
git remote add origin https://github.com/acme/widget.git
mkdir -p cmd/widget internal/widget .github/workflows
cat >go.mod <<'GO'
module github.com/acme/widget

go 1.22
GO
cat >cmd/widget/main.go <<'GO'
// Command widget prints a widget's area.
package main

import (
	"fmt"

	"github.com/acme/widget/internal/widget"
)

func main() {
	fmt.Println(widget.Area(3, 4))
}
GO
cat >internal/widget/widget.go <<'GO'
// Package widget sizes widgets.
package widget

// Area returns the area of a w by h widget.
func Area(w, h int) int {
	return w * h
}
GO
cat >Makefile <<'MK'
.PHONY: build test lint format-check
build:
	go build ./...
test:
	go test ./...
lint:
	go vet ./...
format-check:
	@test -z "$$(gofmt -l .)"
MK
cat >.github/workflows/ci.yml <<'YML'
name: CI
on:
  push:
    branches: [main]
  pull_request:
jobs:
  build:
    name: Build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - run: make build
  test:
    name: Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - run: make test
  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - run: make lint
  format-check:
    name: Format Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - run: make format-check
  all-clear:
    name: All Clear
    runs-on: ubuntu-latest
    needs: [build, test, lint, format-check]
    steps:
      - run: echo "All checks passed"
YML
printf '# widget\n\nSizes widgets.\n' >README.md
git add . && git commit -qm "chore: Initial commit"

sed -e "s|@LOG@|$EVAL_STUB_LOG|g" "$EVAL_FIXTURES/gh-os-repo-stub.sh" >"$EVAL_BIN/gh"
chmod +x "$EVAL_BIN/gh"
