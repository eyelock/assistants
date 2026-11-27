#!/usr/bin/env bash
# Record sensor ask-for-merged: an open merge bead (label inbox:merge) whose pull request has already merged or closed: there is nothing left to merge.
#
# Run in the Wheelhouse's root. Prints one line per item and exits 1 if there is any; exit 3 when it could not read
# what it counts. Plain bash and jq (and bd or gh where it reads them): runs without ynh.
set -uo pipefail
[ "${1:-}" != "--help" ] || { sed -n 2,3p "$0"; exit 0; }
# shellcheck source=../record-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../record-lib.sh"
need jq; need bd; need gh
beads=$(rs_beads open) || exit 3
while IFS=$'\t' read -r id title url; do
  [ -n "$id" ] && [ -n "$url" ] || continue
  state=$(rs_pr_state "$url" || echo unknown)
  case "$state" in MERGED | CLOSED) rs_out "$id: $title ($url is $state)" ;; esac
done < <(jq -r '.[] | select((.labels // []) | index("inbox:merge")) | [.id, .title, (.external_ref // "")] | @tsv' <<<"$beads")
rs_done
