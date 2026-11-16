#!/usr/bin/env bash
# worktrees add: a Wheelhouse (./ynw) with a worktrees.json policy, a checkout (./widget) beside it
# whose origin has develop, and a bead the seat holds. The seat runs the plugin's worktree.sh.
set -euo pipefail
export GIT_CONFIG_GLOBAL=/dev/null
git init -q --bare -b develop origin.git
git clone -q origin.git widget
(
  cd widget
  git checkout -q -b develop
  echo hi > a.txt
  git add a.txt
  git -c user.name=t -c user.email=t@example.com commit -q -m first
  git push -q origin develop
  git fetch -q
)
mkdir -p ynw
printf '# ynw\n\nRepositories, beside ynw: `widget`: `../widget`.\n' > ynw/AGENTS.md
printf '{"layout": "{repo}/.worktrees/{seat}/{branch}"}\n' > ynw/worktrees.json
# bd stands in: it logs each call, and a comment add succeeds.
cat > "$EVAL_BIN/bd" <<'SH'
#!/bin/sh
printf '%s\n' "bd $*" >> "$EVAL_STUB_LOG"
case "$1 $2" in
  "list "*) echo '[{"id":"ynw-7"}]' ;;
  "comments ynw-7") echo '[]' ;;
  *) echo '[]' ;;
esac
SH
chmod +x "$EVAL_BIN/bd"
