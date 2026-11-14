#!/usr/bin/env bash
# Syncs a Wheelhouse's memory and work graph, at a seat's session start and end. It does that and
# nothing else: wake.sh calls it at the start (and for --end), and a seat's session-end hook runs
# wake.sh --end, which hands over to this.
#
# With ynm, memory syncs when the repository has a git remote and the Beads work graph when it has
# a Dolt remote. With Beads, memory and work are one database and one bd sync, with one result for
# both. Each sync is skipped when there is no remote, gives up after WAKE_SYNC_SECS (default 45) at
# a session's start, and never stops the wake. --no-sync skips both.
#
# At a start it prints {memory, work, remote}: each of memory and work is synced, skipped or
# failed, and remote is yes, no or busy (a Dolt-remote check that gave up or failed is not "no
# remote", it is a bd that cannot be reached, which is reported as a failed sync).
#
# With --end it syncs what the session wrote: memory (ynm sync) and the work graph (bd sync),
# each skipped without a remote and run side by side (with Beads, memory and work are one bd sync,
# reported for both; the Dolt-remote check is inside the work sync's budget, a third of it) and
# given up after 25 seconds, inside the 30-second session-end hook (WHEELHOUSE_END_SYNC_SECS sets
# the budget, at most 28). A full sync, not a push alone: when another seat has pushed since, a
# push alone is rejected until it merges. It prints {seat, push {memory, work:
# pushed|skipped|failed|timeout}} and, when a sync did not push, errors {memory, work}: its exit
# code and the first line it printed. With --no-sync it syncs neither and reports both as skipped.
#
# Usage: sync.sh [--end] [--no-sync] [--seat <name>] [--dir <wheelhouse repo>]
# Exit codes: 0 printed, 1 bad args, 2 not a Wheelhouse, 3 a tool it needs (jq, bd, ynm) is missing.
set -uo pipefail

usage() {
  echo "Usage: sync.sh [--end] [--no-sync] [--seat <name>] [--dir <wheelhouse repo>]"
}

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
for lib in "$here/wheelhouse-lib.sh" "$here/../../work-graph/scripts/wheelhouse-lib.sh"; do
  # shellcheck source=../../work-graph/scripts/wheelhouse-lib.sh
  [ -f "$lib" ] && { . "$lib"; break; }
done
type wl_loaded >/dev/null 2>&1 || { echo "wheelhouse-lib.sh not found beside $0 or in the work-graph skill's scripts folder" >&2; exit 3; }
seat="${BEADS_ACTOR:-}"
dir="."
sync=1
end=0
while [ $# -gt 0 ]; do
  case "$1" in
    --seat) [ $# -ge 2 ] || { usage >&2; exit 1; }; seat="$2"; shift 2 ;;
    --dir) [ $# -ge 2 ] || { usage >&2; exit 1; }; dir="$2"; shift 2 ;;
    --no-sync) sync=0; shift ;;
    --end) end=1; shift ;;
    --help | -h) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done
for tool in jq bd; do need "$tool"; done
[ -f "$dir/$WL_ROSTER_REL" ] || { echo "not a Wheelhouse (no $dir/$WL_ROSTER_REL)" >&2; exit 2; }
cd "$dir" || exit 2

# Where memory lives: wheelhouse.json's "memory", ynm when there is no file or no key.
backend=$(wl_backend .) || { echo "wheelhouse.json: memory must be \"ynm\" or \"beads\"" >&2; exit 2; }
if [ "$backend" = ynm ]; then need ynm; fi

sync_secs="${WAKE_SYNC_SECS:-45}"
remote=no

# At the end of a session, sync what it wrote (--no-sync skips both).
if [ "$end" = 1 ]; then
  mempush=skipped
  workpush=skipped
  memerr=""
  workerr=""
  # The two syncs run side by side, each given the same budget, so the worst case is the budget
  # itself, not twice it. The session-end hook gives wake.sh 30 seconds and kills it after that,
  # before the JSON below prints, so the budget stays under it: 25 seconds by default, never more
  # than 28 (WHEELHOUSE_END_SYNC_SECS lowers or raises it within that).
  budget="${WHEELHOUSE_END_SYNC_SECS:-25}"
  case "$budget" in '' | *[!0-9]*) budget=25 ;; esac
  [ "$budget" -gt 28 ] && budget=28
  [ "$budget" -lt 1 ] && budget=1
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/wake-end.XXXXXX")
  # Runs one sync for <secs> seconds and keeps its output in <tmp>/<name>.rc and .err: the exit
  # code (142 when the alarm killed it) and "exit N: first line".
  endsync() {
    local secs="$1" name="$2"; shift 2
    local rc first
    limited "$secs" "$@" >"$tmp/$name.out" 2>&1
    rc=$?
    echo "$rc" >"$tmp/$name.rc"
    if [ "$rc" != 0 ]; then
      first=$(grep -m1 . "$tmp/$name.out" 2>/dev/null | cut -c1-200)
      printf '%s' "exit $rc${first:+: $first}" >"$tmp/$name.err"
    fi
  }
  # The work sync, with its Dolt-remote check in the same budget (at most a third for the check,
  # the sync gets what is left of it), run in the background beside the memory sync. A check that
  # gave up or failed is a failed sync, not "no remote".
  endwork() {
    local check=$(( budget / 3 )) began=$SECONDS rest
    [ "$check" -ge 1 ] || check=1
    remote=$(wl_dolt_remote "$check")
    # SECONDS counts whole seconds, so one more is held back for the rounding.
    rest=$(( budget - (SECONDS - began) - 1 ))
    [ "$rest" -ge 1 ] || rest=1
    if [ "$remote" = busy ]; then
      echo 142 >"$tmp/work.rc"; printf '%s' "exit 142: the Dolt-remote check gave up or failed (bd busy)" >"$tmp/work.err"
    elif [ "$remote" = yes ]; then
      endsync "$rest" work bd sync
    fi
  }
  # With Beads, memory and work are one database: one bd sync, and its result is both.
  if [ "$backend" = ynm ]; then
    if [ "$sync" = 1 ] && wl_has_git_remote; then endsync "$budget" mem ynm sync --quiet & fi
    if [ "$sync" = 1 ]; then endwork & fi
  else
    if [ "$sync" = 1 ]; then endwork & fi
  fi
  wait
  if [ "$backend" = beads ]; then
    for f in rc err; do [ -f "$tmp/work.$f" ] && cp "$tmp/work.$f" "$tmp/mem.$f"; done
  fi
  # <var> becomes pushed, timeout or failed from the sync's exit code; <errvar> its error text.
  endresult() {
    local name="$1" var="$2" errvar="$3" rc
    [ -f "$tmp/$name.rc" ] || return 0
    rc=$(cat "$tmp/$name.rc")
    if [ "$rc" = 0 ]; then printf -v "$var" pushed
    else
      if [ "$rc" = 142 ]; then printf -v "$var" timeout; else printf -v "$var" failed; fi
      printf -v "$errvar" '%s' "$(cat "$tmp/$name.err")"
    fi
  }
  endresult mem mempush memerr
  endresult work workpush workerr
  rm -rf "$tmp"
  jq -nc --arg seat "$seat" --arg m "$mempush" --arg w "$workpush" --arg me "$memerr" --arg we "$workerr" \
    '{seat: $seat, push: {memory: $m, work: $w}} + (if $me != "" or $we != "" then {errors: ({memory: $me, work: $we} | with_entries(select(.value != "")))} else {} end)'
  exit 0
fi

# At a session's start, sync first, so what follows is current.
memsync=skipped
worksync=skipped
if [ "$sync" = 1 ]; then
  if [ "$backend" = ynm ]; then
    if wl_has_git_remote; then
      if limited "$sync_secs" ynm sync --quiet >/dev/null 2>&1; then memsync=synced; else memsync=failed; fi
    fi
    remote=$(wl_dolt_remote "$sync_secs")
    if [ "$remote" = busy ]; then worksync=failed
    elif [ "$remote" = yes ]; then
      if limited "$sync_secs" bd sync >/dev/null 2>&1; then worksync=synced; else worksync=failed; fi
    fi
  else
    # Memory and work are one database: one sync, one result for both.
    remote=$(wl_dolt_remote "$sync_secs")
    if [ "$remote" = busy ]; then memsync=failed
    elif [ "$remote" = yes ]; then
      if limited "$sync_secs" bd sync >/dev/null 2>&1; then memsync=synced; else memsync=failed; fi
    fi
    worksync=$memsync
  fi
fi
jq -nc --arg m "$memsync" --arg w "$worksync" --arg r "$remote" '{memory: $m, work: $w, remote: $r}'
