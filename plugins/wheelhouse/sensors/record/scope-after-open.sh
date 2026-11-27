#!/usr/bin/env bash
# Record sensor scope-after-open: an issue put into an open milestone on a later day than the milestone was created: scope added to a release already open.
#
# Run in the Wheelhouse's root. Prints one line per item and exits 1 if there is any; exit 3 when it could not read
# what it counts. Plain bash and jq (and bd or gh where it reads them): runs without ynh.
set -uo pipefail
# GitHub records when an issue was milestoned, in the repository's issue events (the last page of 100). A milestone's opening date is
# the day GitHub records it was created.
[ "${1:-}" != "--help" ] || { sed -n 2,3p "$0"; exit 0; }
# shellcheck source=../record-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../record-lib.sh"
need jq; need gh
repos=$(wl_repos .) || die 3 "no repositories to read: set WHEELHOUSE_REPOS or name them under What it reaches"
for r in $repos; do
  ms=$(limited "$WL_GH_SECS" gh api "repos/$r/milestones?state=open&per_page=100" 2>/dev/null) || die 3 "gh could not list $r's milestones"
  ev=$(limited "$WL_GH_SECS" gh api "repos/$r/issues/events?per_page=100" 2>/dev/null) || die 3 "gh could not read $r's issue events"
  while IFS= read -r line; do
    [ -n "$line" ] && rs_out "$r $line"
  done < <(jq -r --argjson ev "$ev" '
    .[] as $m
    | $ev[] | select(.event == "milestoned" and .milestone.title == $m.title)
    | select((.created_at[0:10]) > ($m.created_at[0:10]))
    | "#\(.issue.number // "?") \(.issue.title // "") added to \($m.title) on \(.created_at[0:10]), after it opened on \($m.created_at[0:10])"' <<<"$ms")
done
rs_done
