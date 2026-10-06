#!/usr/bin/env bash
# Prints what a release run left behind, for the judge: origin's history, each
# tag on origin with its type and the branches holding it, origin's refs, the
# pull requests opened through gh, and the local repository's state.
# Exit codes: 0 success.
set -uo pipefail

origin=.eval/origin.git
git() { command -p git "$@"; }

echo "\$ git log --graph --all (origin)"
git --git-dir="$origin" log --oneline --graph --decorate --all -n 20
echo
echo "Tags on origin:"
for tag in $(git --git-dir="$origin" tag -l); do
  type="$(git --git-dir="$origin" cat-file -t "$tag")"
  commit="$(git --git-dir="$origin" rev-parse --short "$tag^{commit}")"
  subject="$(git --git-dir="$origin" log -1 --format=%s "$commit")"
  on="$(git --git-dir="$origin" branch --contains "$commit" --format='%(refname:short)' | tr '\n' ' ')"
  heads="$(git --git-dir="$origin" for-each-ref refs/heads --points-at "$commit" --format='%(refname:short)' | tr '\n' ' ')"
  echo "  $tag: $( [[ $type == tag ]] && echo annotated || echo lightweight ) tag on $commit \"$subject\"; tip of: ${heads:-none}; reachable from: ${on:-none}"
done
echo
echo "\$ git ls-remote origin"
git ls-remote "$origin"
echo
echo "Pull requests (number, head, base, state, title):"
cat .eval/prs 2>/dev/null || echo "(none)"
echo
echo "\$ git status -sb (local)"
git status -sb | head -5
echo
echo "\$ git log --oneline -n 3 (local HEAD)"
git log --oneline -n 3
