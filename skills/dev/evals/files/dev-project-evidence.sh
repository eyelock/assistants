#!/usr/bin/env bash
# Prints what a dev-project run scaffolded, for the judge: every file outside
# .git and dependency or build directories, the contents of the small config
# files, each new repository's commits, and, for a Go project, its build and
# test and lint targets run fresh.
# Exit codes: 0 success.
set -uo pipefail

echo "\$ find . (files created)"
find . -path ./.eval -prune -o -name .git -prune -o -name node_modules -prune -o -type f -print | sort
echo
for f in $(find . -path ./.eval -prune -o -name .git -prune -o -name node_modules -prune -o -type f \( -name Makefile -o -name 'go.mod' -o -name '.gitignore' -o -name 'package.json' -o -name 'tsconfig*.json' -o -name '.golangci.y*ml' -o -name '*eslint*' -o -name '.prettierrc*' -o -name 'vitest.config.*' -o -name 'README.md' \) -print | sort); do
  echo "--- $f"
  head -80 "$f"
  echo
done
for g in $(find . -path ./.eval -prune -o -name .git -type d -print); do
  dir="$(dirname "$g")"
  echo "\$ git -C $dir log --oneline --stat"
  git -C "$dir" log --oneline --stat 2>&1 | head -40
  echo "\$ git -C $dir status --short"
  git -C "$dir" status --short 2>&1 | head -20
done
for m in $(find . -path ./.eval -prune -o -name go.mod -print); do
  dir="$(dirname "$m")"
  for t in build test lint; do
    echo "\$ make -C $dir $t"
    # No VCS stamping: the OS sandbox may have kept git init from writing .git/config.
    GOFLAGS="-mod=mod -buildvcs=false" make -C "$dir" "$t" 2>&1 | tail -15
    echo "exit=${PIPESTATUS[0]}"
  done
done
