#!/usr/bin/env bash
# worktrees dirty: as worktrees-add, with the worktree already made and an uncommitted file in it.
set -euo pipefail
. "$EVAL_FIXTURES/worktrees-add.sh"
git -C widget worktree add -q -b albarn/fix-a widget/.worktrees/albarn/albarn/fix-a origin/develop
echo scratch > widget/.worktrees/albarn/albarn/fix-a/new.txt
