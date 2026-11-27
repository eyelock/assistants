#!/usr/bin/env bash
# record-lib.sh: what the record sensors (sensors/record/*.sh) share. Source it; never run it.
#
# A record sensor is advisory: it reads the work graph, GitHub or the patrol's own files (not the
# tree under test), prints one line per item it counts, and exits 1 when there is any. Run from
# the Wheelhouse's root. Exit 3 means "could not read what I count": that is not a zero.
# It needs bash, jq and, where it reads them, bd and gh; never ynh.
#
# Interface (on top of wheelhouse-lib.sh, which this sources)
#   rs_done            exit 1 when the sensor printed any line, else 0 (call it last)
#   rs_beads STATUS    print the Wheelhouse's beads in that status as a JSON array; exit 3 if bd fails
#   rs_pr_state URL    print OPEN, MERGED or CLOSED for a pull request URL; return 1 when gh can't say
#   rs_note_url BEAD   (stdin: a bead JSON) print the last "PR: <url>" in its notes, or nothing
#   rs_patrol_file     print the patrol snapshot's path: $WHEELHOUSE_PATROL_FILE, else .wheelhouse/patrol.json
#   rs_out LINE...     print one finding line and count it

# shellcheck shell=bash

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
for lib in "$here/../skills/work-graph/scripts/wheelhouse-lib.sh" "$here/wheelhouse-lib.sh"; do
  # shellcheck source=../skills/work-graph/scripts/wheelhouse-lib.sh
  [ -f "$lib" ] && { . "$lib"; break; }
done
type wl_loaded >/dev/null 2>&1 || { echo "wheelhouse-lib.sh not found: it is in the work-graph skill's scripts folder" >&2; exit 3; }
WL_PREFIX="${WL_PREFIX:-record sensor: }"

RS_FOUND=0
rs_out() { printf '%s\n' "$*"; RS_FOUND=$((RS_FOUND + 1)); }
rs_done() { [ "$RS_FOUND" -eq 0 ]; }

rs_beads() {
  local out
  out=$(limited "$WL_BD_SECS" bd list --status "$1" --limit 0 --json 2>/dev/null) || die 3 "bd could not list the $1 beads"
  bd_data <<<"$out" | jq -c 'if type == "array" then . else [] end' || die 3 "bd's answer was not JSON"
}

rs_pr_state() {
  local s
  s=$(limited "$WL_GH_SECS" gh pr view "$1" --json state --jq .state 2>/dev/null) || return 1
  case "$s" in OPEN | MERGED | CLOSED) printf '%s\n' "$s" ;; *) return 1 ;; esac
}

rs_note_url() { jq -r '[(.notes // "") | scan("PR: (https?://[^ \n]+)") | .[0]] | last // empty'; }

rs_patrol_file() { printf '%s\n' "${WHEELHOUSE_PATROL_FILE:-.wheelhouse/patrol.json}"; }
