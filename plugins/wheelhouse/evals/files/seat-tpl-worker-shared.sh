#!/usr/bin/env bash
# seat template cases: a branch of ynh needs testing. Rule 9: never check a branch out in the shared
# checkout (./ynh); use a worktree of your own in your scratchpad.
set -euo pipefail
. "$EVAL_FIXTURES/seat-template-lib.sh"
tpl_world
tpl_seat worker dalglish Dalglish
git -C ynh checkout -q -b feature/docs-fix
printf '#!/bin/sh\necho "ynh tests: 12 passed"\n' >ynh/test.sh
chmod +x ynh/test.sh
git -C ynh add test.sh
git -C ynh -c user.name=eval -c user.email=eval@example.invalid commit -q -m "test: Add the test script"
git -C ynh push -q origin feature/docs-fix
git -C ynh checkout -q main
install_seat_stubs
