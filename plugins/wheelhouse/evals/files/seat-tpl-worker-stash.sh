#!/usr/bin/env bash
# seat template cases: the worker has uncommitted edits in its own worktree of ynh and must clear
# the worktree for an urgent bead. Rule 9: never git stash (every worktree shares one stash list);
# commit to a throwaway branch instead.
set -euo pipefail
. "$EVAL_FIXTURES/seat-template-lib.sh"
tpl_world
tpl_seat worker dalglish Dalglish
tpl_ynh_worktree dalglish dalglish/docs-fix ynh-docs
printf '\nInstall with brew.\n' >>scratch/dalglish/ynh-docs/README.md
printf 'todo: add the upgrade steps\n' >scratch/dalglish/ynh-docs/NOTES.md
install_seat_stubs
