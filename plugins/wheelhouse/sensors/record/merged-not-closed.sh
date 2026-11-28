#!/usr/bin/env bash
# Record sensor merged-not-closed: an open bead whose notes carry 'PR: <url>' for a pull request that has merged: the work is done and the bead is not closed.
#
# Run in the Wheelhouse's root. Prints one line per item and exits 1 if there is any; exit 3 when it could not read
# what it counts. Plain bash and jq (and bd or gh where it reads them): runs without ynh.
set -uo pipefail
[ "${1:-}" != "--help" ] || { sed -n 2,3p "$0"; exit 0; }
# shellcheck source=../record-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../record-lib.sh"
need jq; need bd; need gh
for status in open in_progress; do
  beads=$(rs_beads "$status") || exit 3
  while IFS=$'\t' read -r id title url; do
    [ -n "$id" ] && [ -n "$url" ] || continue
    # When gh can't say, the bead is neither done nor not: exit 3, never a count.
    state=$(rs_pr_state "$url") || die 3 "could not read the state of $url (gh is missing, slow or failing)"
    [ "$state" != MERGED ] || rs_out "$id: $title ($url merged)"
  done < <(jq -r '.[] | select((.labels // []) | any(startswith("session:")) | not)
    | [.id, .title, ((.notes // "") | [scan("PR: (https?://[^ \n]+)") | .[0]] | last // "")] | @tsv' <<<"$beads")
done
rs_done
