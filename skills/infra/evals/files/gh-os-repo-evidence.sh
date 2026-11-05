#!/usr/bin/env bash
# Prints what a gh-os-repo run left in the checkout, for the judge: every file
# outside .git with the contents of each file under .github/ and the root
# community files, and what is uncommitted. The gh calls follow in the stub log.
# Exit codes: 0 success.
set -uo pipefail

echo "\$ find . -type f (outside .git and .eval)"
find . -path ./.git -prune -o -path ./.eval -prune -o -type f -print | sort
echo
for f in $(find .github -type f 2>/dev/null | sort) LICENSE LICENSE.md CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md; do
  [[ -f "$f" ]] || continue
  echo "--- $f"
  head -60 "$f"
  echo
done
echo "\$ git status --short"
git status --short
