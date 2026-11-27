#!/usr/bin/env bash
# Record sensor stale-claims: an in-progress bead with no live claim: its lease has lapsed and no open pull request is waiting on it.
#
# Run in the Wheelhouse's root. Prints one line per item and exits 1 if there is any; exit 3 when it could not read
# what it counts. Plain bash and jq (and bd or gh where it reads them): runs without ynh.
set -uo pipefail
# A seat's session hold (label session:<command>) is claimed with no lease on purpose and is left out.
[ "${1:-}" != "--help" ] || { sed -n 2,3p "$0"; exit 0; }
# shellcheck source=../record-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../record-lib.sh"
need jq; need bd
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
beads=$(rs_beads in_progress) || exit 3
while IFS=$'\t' read -r id title who lease url; do
  [ -n "$id" ] || continue
  if [ -n "$url" ]; then
    # An open pull request means the bead waits on a review or a merge: never a dead claim.
    # When gh can't say, the claim is neither live nor dead: exit 3, never a count.
    state=$(rs_pr_state "$url") || die 3 "could not read the state of $url (gh is missing, slow or failing)"
    [ "$state" != OPEN ] || continue
  fi
  if [ -n "$lease" ]; then ended="lease ended $lease"; else ended="no lease at all"; fi
  rs_out "$id: $title (held by ${who:-no one}, $ended)"
done < <(jq -r --arg now "$now" '.[]
  | select((.labels // []) | any(startswith("session:")) | not)
  | select((.lease_expires_at // "") < $now)
  | [.id, .title, (.assignee // ""), (.lease_expires_at // ""), (.notes // "" | [scan("PR: (https?://[^ \n]+)") | .[0]] | last // "")] | @tsv' <<<"$beads")
rs_done
