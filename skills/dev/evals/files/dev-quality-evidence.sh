#!/usr/bin/env bash
# Prints what a dev-quality run left behind, for the judge: commits made, the
# working tree's state, any change to the Makefile or lint tool, every Go
# change since main (tests included), a fresh run of each Makefile gate, and
# per-function test coverage of the pricing package, all on the working tree.
# Exit codes: 0 success.
set -uo pipefail
git() { command -p git "$@"; }

echo "\$ git log --oneline main..HEAD (commits made in the run)"
git log --oneline main..HEAD
echo
echo "\$ git status --short"
git status --short
echo
# A scratch index, so untracked files show in the diffs without touching the repo's.
export GIT_INDEX_FILE=.eval/evidence-index
rm -f "$GIT_INDEX_FILE"
git add -A . >/dev/null 2>&1
echo "\$ git diff main -- Makefile tools/ (changes to the gates themselves)"
git diff --cached main -- Makefile tools/
echo
echo "\$ git diff main -- '*.go' (every Go change since main)"
git diff --cached main -- '*.go' ':!tools/'
unset GIT_INDEX_FILE
echo
for target in build lint format-check test; do
  echo "\$ make $target"
  command -p make "$target" 2>&1
  echo "exit=$?"
done
echo
echo "\$ go tool cover -func (per-function test coverage of pricing)"
go test -coverprofile=.eval/cover.out ./pricing >/dev/null 2>&1 && go tool cover -func=.eval/cover.out
