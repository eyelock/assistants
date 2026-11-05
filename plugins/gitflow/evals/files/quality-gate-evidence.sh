#!/usr/bin/env bash
# Prints what a quality-gate run left behind, for the judge: the branch's
# commits and what each changed, what is still uncommitted, how the Makefile
# and the lint tool differ from the start, every Go change since main, and a
# fresh run of every gate on the committed HEAD.
# Exit codes: 0 success.
set -uo pipefail
git() { command -p git "$@"; }

echo "\$ git log --stat main..HEAD (commits made in the run)"
git log --stat --format='--- %h %s' main..HEAD
echo
echo "\$ git status --short (left uncommitted)"
git status --short
echo
# A scratch index, so untracked files show in the diffs without touching the repo's.
export GIT_INDEX_FILE=.eval/evidence-index
rm -f "$GIT_INDEX_FILE"
git add -A . >/dev/null 2>&1
echo "\$ git diff main -- Makefile tools/ (changes to the gates themselves)"
git diff --cached main -- Makefile tools/
echo
echo "\$ git diff main -- '*.go' (every Go change since main, committed or not)"
git diff --cached main -- '*.go' ':!tools/'
unset GIT_INDEX_FILE
echo
echo "\$ make check, run on a clean export of the committed HEAD"
rm -rf .eval/head && mkdir -p .eval/head && git archive HEAD | tar -x -C .eval/head
(cd .eval/head && command -p make check 2>&1; echo "exit=$?")
