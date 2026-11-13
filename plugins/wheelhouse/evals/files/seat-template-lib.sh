#!/usr/bin/env bash
# Shared by the seat-template eval setups (seat-tpl-*.sh): the paired cases for the plugin's seat
# templates. Builds on seat-fixture.sh (the test Wheelhouse, its sibling checkouts and the
# recording, refusing stubs). Source it, then call:
#
#   tpl_world                 lay out the Wheelhouse in the current directory (the run's directory):
#                             ./hq, a sibling checkout of each YN repository (./ynh and so on, the
#                             shared checkouts) with ynh given a bare origin, and ./scratch, the
#                             seats' scratchpad; Dalglish is the worker seat in the roster
#   tpl_seat <template> <command> <Name>
#                             a seat harness at ./hq/harnesses/<command>, to wake with
#                             "seat": "hq/harnesses/<command>". Its charter is the plugin's seat
#                             template (add-seat/assets/starter-team/<template>.md) with its front
#                             matter taken off, then the Wheelhouse's constitution, as a seat run from
#                             the Wheelhouse would read it. Its session-start hook logs
#                             "seat-woke: <command>" in $EVAL_STUB_LOG.
#   tpl_charter <command> <Name> <file>
#                             the same, for a seat with no template (the coach): the charter is <file>
#   tpl_desk                  the desk: run in ./hq after inbox_wheelhouse, it makes hq itself the
#                             harness (its charter is the constitution's "The desk" section)
#   tpl_pr_view <text>        what "gh pr view" prints (the stub's canned answer)
#
# The plugin has no coach template and no desk template: create-wheelhouse writes the desk's
# charter into the constitution, and the coach is a seat of the Wheelhouse's own. Those cases
# take their charter from tpl_charter and tpl_desk instead.
# Needs what seat-fixture.sh needs. Exit codes: 0 success, 3 tool error.

. "$EVAL_FIXTURES/seat-include.sh"
set -euo pipefail

. "$EVAL_FIXTURES/seat-fixture.sh"

TPL_DIR="$EVAL_FIXTURES/../../skills/add-seat/assets/starter-team"
export TPL_PR="https://github.com/eyelock/ynh/pull/7"

tpl_world() {
  seat_world "$PWD" Dalglish
  mkdir -p scratch
  git init -q --bare origin-ynh.git
  printf '# ynh\n\nThe YN harness manager.\n' >ynh/README.md
  git -C ynh add README.md
  git -C ynh -c user.name=eval -c user.email=eval@example.invalid commit -q -m "docs: Add the readme"
  git -C ynh remote add origin "$PWD/origin-ynh.git"
  git -C ynh push -q origin main
  git -C ynh fetch -q origin
}

# The seat harness: charter on stdin, then the constitution.
tpl_harness() {
  local cmd=$1 name=$2 dir=hq/harnesses/$1
  mkdir -p "$dir/.agents/harness" "scratch/$cmd"
  {
    printf '# %s\n\nYou are %s, the `%s` seat of the hq Wheelhouse. You act in the work graph as `%s`:\n' "$name" "$name" "$cmd" "$cmd"
    printf 'pass `--actor %s` on every `bd` command that changes it. The Wheelhouse is the directory\n' "$cmd"
    printf '`hq/` under your working directory (run `bd` from there, and read the relative paths in\n'
    printf 'its constitution from there: `../ynh` is `./ynh`). Your scratchpad is `./scratch/%s`.\n\n' "$cmd"
    cat
    printf '\n## The constitution\n\n'
    cat hq/AGENTS.md
  } >"$dir/AGENTS.md"
  jq -n --arg c "$cmd" --arg n "$name" '{
    "$schema": "https://eyelock.github.io/ynh/schema/plugin.schema.json",
    name: $c, version: "0.1.0", description: "\($n), a seat of the hq Wheelhouse.",
    default_vendor: "claude",
    hooks: {on_session_start: [{command: "printf \"seat-woke: \($c)\\n\" >> \"$EVAL_STUB_LOG\""}]},
    env_passthrough: ["EVAL_STUB_LOG"],
    workspace: ["../../../ynh"]
  }' >"$dir/.agents/harness/plugin.json"
  seat_include_plugin "$dir/.agents/harness/plugin.json"
}

tpl_seat() {
  awk 'BEGIN { fm = 0 } /^---$/ && fm < 2 { fm++; next } fm >= 2' "$TPL_DIR/$1.md" | tpl_harness "$2" "$3"
}

tpl_charter() { tpl_harness "$1" "$2" <"$3"; }

tpl_desk() {
  mkdir -p .agents/harness
  jq -n '{"$schema": "https://eyelock.github.io/ynh/schema/plugin.schema.json",
    name: "hq", version: "0.1.0", description: "The desk of the hq Wheelhouse.", default_vendor: "claude",
    hooks: {on_session_start: [{command: "printf \"seat-woke: hq\\n\" >> \"$EVAL_STUB_LOG\""}]},
    env_passthrough: ["EVAL_STUB_LOG"]}' >.agents/harness/plugin.json
  seat_include_plugin .agents/harness/plugin.json
}

tpl_pr_view() { seat_gh_answer pr view "$1"; }

# tpl_ynh_worktree <command> <branch> <name>: a worktree of ./ynh for that seat, at
# ./scratch/<command>/<name>, on a new branch off main.
tpl_ynh_worktree() {
  mkdir -p "scratch/$1"
  git -C ynh worktree add -q -b "$2" "$PWD/scratch/$1/$3" main
}
