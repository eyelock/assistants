#!/usr/bin/env bash
# Record sensor ready-without-ask: a pull request out of draft, with a review whose body holds the verdict '✅ ready to merge', and no open merge bead (label inbox:merge) for it.
#
# Run in the Wheelhouse's root. Prints one line per item and exits 1 if there is any; exit 3 when it could not read
# what it counts. Plain bash and jq (and bd or gh where it reads them): runs without ynh.
set -uo pipefail
[ "${1:-}" != "--help" ] || { sed -n 2,3p "$0"; exit 0; }
# shellcheck source=../record-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../record-lib.sh"
need jq; need bd; need gh
repos=$(wl_repos .) || die 3 "no repositories to read: set WHEELHOUSE_REPOS or name them under What it reaches"
beads=$(rs_beads open) || exit 3
open_merge=$(jq -c '[.[] | select((.labels // []) | index("inbox:merge")) | .external_ref // empty]' <<<"$beads")
for r in $repos; do
  prs=$(limited "$WL_GH_SECS" gh pr list -R "$r" --state open --limit 100 --json number,title,url,isDraft,reviews 2>/dev/null) || die 3 "gh could not list $r's pull requests"
  while IFS=$'\t' read -r url title; do
    [ -n "$url" ] || continue
    rs_out "$title ($url has a ready verdict and no merge bead)"
  done < <(jq -r --argjson merges "$open_merge" '.[]
    | select(.isDraft | not)
    | select(any(.reviews[]?; (.body // "") | contains("✅ ready to merge")))
    | select(.url as $u | $merges | index($u) | not)
    | [.url, .title] | @tsv' <<<"$prs")
done
rs_done
