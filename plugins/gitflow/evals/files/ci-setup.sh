#!/usr/bin/env bash
# Builds the ci skill's sandbox in the current directory: the acme/widget Go
# repository (main, develop, release/* and hotfix/* branches; releases are cut
# by pushing v* tags) with a Makefile holding its gates, docs, and no
# workflows yet.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail

cat >go.mod <<'GO'
module github.com/acme/widget

go 1.22
GO
mkdir -p cmd/widget internal/widget docs
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
.PHONY: build lint format-check test check dist

build:
	go build ./...

lint:
	go vet ./...

format-check:
	@test -z "$$(gofmt -l .)" || { gofmt -l .; exit 1; }

test:
	go test ./...

# All four gates, as run before every commit.
check: build lint format-check test

# Release archives, into dist/.
dist:
	mkdir -p dist
	GOOS=linux GOARCH=amd64 go build -o dist/widget-linux-amd64 ./cmd/widget
	GOOS=darwin GOARCH=arm64 go build -o dist/widget-darwin-arm64 ./cmd/widget
MK
cat >README.md <<'MD'
# widget

Sizes widgets. `make check` runs the build, lint, format and test gates; `make dist`
builds the release binaries.

Branches follow Gitflow: features merge to `develop`, releases go through
`release/vX.Y.Z` into `main`, fixes to production through `hotfix/vX.Y.Z`, and a
release is published by pushing a `vX.Y.Z` tag on `main`.
MD
cat >docs/usage.md <<'MD'
# Usage

    widget
MD
