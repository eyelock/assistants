#!/usr/bin/env bash
# Prints what an add-seat eval left behind: the shared checkout's branch and
# status and the worktree list, then every seat harness and charter, the desk's
# delegates and the roster's seats, as read from the newest seat/* trial branch.
set -uo pipefail
# The shared checkout first: a seat written there, or a worktree left behind, must show.
echo '$ git branch --show-current'; git branch --show-current
echo '$ git status --short'; git status --short --untracked-files=all | grep -v -e '^?? .beads/' -e '^?? .eval/'
echo '$ git worktree list'; git worktree list
# A seat is written on a trial branch seat/<command>; read the newest one in a
# temporary worktree of our own, removed on exit, since the seating seat removes its own.
b=$(git for-each-ref --sort=-committerdate --format='%(refname:short)' 'refs/heads/seat/*' | head -n1)
if [ -n "$b" ]; then
  root=$(pwd)
  t=$(mktemp -d)
  trap 'cd / && git -C "$root" worktree remove --force "$t" 2>/dev/null; rm -rf "$t"' EXIT
  git worktree add -q --detach "$t" "$b" && cd "$t" || exit 1
  echo; echo "\$ trial branch: $b"
fi
for h in harnesses/*/; do
  [ -d "$h" ] || continue
  echo; echo "\$ cat ${h}.agents/harness/plugin.json"; cat "${h}.agents/harness/plugin.json" 2>/dev/null || echo "(missing)"
  echo; echo "\$ cat ${h}AGENTS.md"; cat "${h}AGENTS.md" 2>/dev/null || echo "(missing)"
done
echo; echo '$ desk delegates_to'; jq -c '.delegates_to' .agents/harness/plugin.json
echo; echo '$ roster seats'; jq -c '.seats[]' skills/roster/assets/roster.json
