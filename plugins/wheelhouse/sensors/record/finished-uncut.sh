#!/usr/bin/env bash
# Record sensor finished-uncut: an open milestone with nothing open in it and at least one closed issue, whose version has no release tag in the repository.
#
# Run in the Wheelhouse's root. Prints one line per item and exits 1 if there is any; exit 3 when it could not read
# what it counts. Plain bash and jq (and bd or gh where it reads them): runs without ynh.
set -uo pipefail
# The version is the first N.N.N in the milestone's title; a tag matches when its name ends with it, with or without a leading v.
[ "${1:-}" != "--help" ] || { sed -n 2,3p "$0"; exit 0; }
# shellcheck source=../record-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../record-lib.sh"
need jq; need gh
repos=$(wl_repos .) || die 3 "no repositories to read: set WHEELHOUSE_REPOS or name them under What it reaches"
for r in $repos; do
  ms=$(limited "$WL_GH_SECS" gh api "repos/$r/milestones?state=open&per_page=100" 2>/dev/null) || die 3 "gh could not list $r's milestones"
  tags=$(limited "$WL_GH_SECS" gh api "repos/$r/tags?per_page=100" --jq '.[].name' 2>/dev/null) || die 3 "gh could not list $r's tags"
  while IFS=$'\t' read -r title ver; do
    [ -n "$title" ] || continue
    if [ -n "$ver" ] && grep -Eq "(^|[^0-9.])v?${ver//./\\.}$" <<<"$tags"; then continue; fi
    rs_out "$r $title (nothing open, no release tag)"
  done < <(jq -r '.[] | select(.open_issues == 0 and .closed_issues > 0)
    | [.title, ((.title | capture("(?<v>[0-9]+\\.[0-9]+\\.[0-9]+)") | .v) // "")] | @tsv' <<<"$ms")
done
rs_done
