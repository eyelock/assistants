#!/usr/bin/env bash
# Builds the release skill's sandbox in the current directory: the acme/widget
# Go repo whose origin is a local bare repository (.eval/origin.git). main was
# released as v1.3.0 through release/v1.3.0; develop has since gained a feature
# and a fix. The working copy is on develop, in sync with origin. A gh that
# answers like GitHub (release-gh-stub.sh) goes first on PATH: its PR merges
# really merge on origin, and its release runs follow the tags origin holds.
# git and make are real, wrapped so each call is logged as well.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail

work="$PWD"
origin="$work/.eval/origin.git"

git init -q --bare "$origin"
git init -q -b main .
echo ".eval/" >>.git/info/exclude
git remote add origin "$origin"

cat >go.mod <<'EOF'
module github.com/acme/widget

go 1.22
EOF
mkdir -p widget .github/workflows
cat >widget/widget.go <<'EOF'
// Package widget sizes widgets.
package widget

// Area returns the area of a w by h widget.
func Area(w, h int) int {
	return w * h
}
EOF
cat >widget/widget_test.go <<'EOF'
package widget

import "testing"

func TestArea(t *testing.T) {
	if got := Area(3, 4); got != 12 {
		t.Fatalf("Area(3, 4) = %d, want 12", got)
	}
}
EOF
cat >Makefile <<'EOF'
.PHONY: build lint format-check test check

build:
	go build ./...

lint:
	go vet ./...

format-check:
	@test -z "$$(gofmt -l .)" || { gofmt -l .; echo "error: files need gofmt"; exit 1; }

test:
	go test ./...

# The quality gate: all four must pass before a commit or a release tag.
check: build lint format-check test
EOF
cat >.github/workflows/release.yml <<'EOF'
name: Release

on:
  push:
    tags: ['v*']

jobs:
  verify-ci:
    name: Verify CI Passed
    runs-on: ubuntu-latest
    steps:
      - run: echo "checks CI passed on the tagged commit"
  build-and-release:
    name: Build and Release
    needs: verify-ci
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
      - run: make build
      - uses: softprops/action-gh-release@v2
        with:
          prerelease: ${{ contains(github.ref_name, '-') }}
          generate_release_notes: true
EOF
git add . && git commit -qm "chore: Initial commit"
git push -q -u origin main

git checkout -qb develop
git push -q -u origin develop

# v1.3.0 went out the Gitflow way: release branch, merge into main, tag on main.
git checkout -qb release/v1.3.0
git commit -q --allow-empty -m "chore(release): Prepare v1.3.0"
git checkout -q main
git merge -q --no-ff release/v1.3.0 -m "Merge pull request #51 from acme/release/v1.3.0"
git tag -a v1.3.0 -m "Release v1.3.0"
git push -q origin main v1.3.0
git checkout -q develop
git merge -q --no-ff main -m "chore: Back-merge release/v1.3.0 into develop"
git branch -q -D release/v1.3.0

# Work merged to develop since v1.3.0: a feature and a fix, nothing breaking.
cat >widget/perimeter.go <<'EOF'
package widget

// Perimeter returns the perimeter of a w by h widget.
func Perimeter(w, h int) int {
	return 2 * (w + h)
}
EOF
git add widget && git commit -qm "feat: Widgets report their perimeter (#53)"
cat >widget/widget.go <<'EOF'
// Package widget sizes widgets.
package widget

// Area returns the area of a w by h widget, or 0 when either side is negative.
func Area(w, h int) int {
	if w < 0 || h < 0 {
		return 0
	}
	return w * h
}
EOF
git commit -qam "fix: Negative sides give a zero area (#55)"
git push -q -u origin develop

real_git="$(command -v git)"
sed -e "s|@ORIGIN@|$origin|g" -e "s|@LOG@|$EVAL_STUB_LOG|g" -e "s|@GIT@|$real_git|g" \
  "$EVAL_FIXTURES/release-gh-stub.sh" >"$EVAL_BIN/gh"
# git and make run for real, but each call is logged too, so the order of
# merge, quality gate and tag shows in the stub log. Claude Code's own git
# calls, which start with -c, are left out.
for tool in git make; do
  real="$(command -v "$tool")"
  printf '#!/bin/sh\n[ "$1" = -c ] || printf "%%s\\n" "%s $*" >>"%s"\nexec "%s" "$@"\n' "$tool" "$EVAL_STUB_LOG" "$real" >"$EVAL_BIN/$tool"
done
chmod +x "$EVAL_BIN/gh" "$EVAL_BIN/git" "$EVAL_BIN/make"
