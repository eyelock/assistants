#!/usr/bin/env bash
# Record sensor patrol-alive: 1 if the patrol's last run is older than twice its interval. Reads at and interval_minutes from the patrol's snapshot.
#
# Run in the Wheelhouse's root. Prints one line per item and exits 1 if there is any; exit 3 when it could not read
# what it counts. Plain bash and jq (and bd or gh where it reads them): runs without ynh.
set -uo pipefail
# No snapshot means no patrol has run here, so there is nothing to be alive: it prints nothing.
[ "${1:-}" != "--help" ] || { sed -n 2,3p "$0"; exit 0; }
# shellcheck source=../record-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../record-lib.sh"
need jq
file=$(rs_patrol_file)
[ -f "$file" ] || exit 0
read -r at interval < <(jq -r '[(.at // 0), (.interval_minutes // 5)] | @tsv' "$file" 2>/dev/null) || die 3 "$file isn't JSON"
[ "$at" != 0 ] || exit 0
now=${WHEELHOUSE_NOW:-$(date +%s)}
age=$(((now - at) / 60))
[ "$age" -le $((interval * 2)) ] || rs_out "the patrol last ran $age minutes ago, over twice its $interval-minute interval"
rs_done
