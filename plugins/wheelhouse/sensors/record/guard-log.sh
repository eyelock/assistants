#!/usr/bin/env bash
# Record sensor guard-log: lines in the guard log (.wheelhouse/guard.log, or $WHEELHOUSE_GUARD_LOG) written since the patrol's last run.
#
# Run in the Wheelhouse's root. Prints one line per item and exits 1 if there is any; exit 3 when it could not read
# what it counts. Plain bash and jq (and bd or gh where it reads them): runs without ynh.
set -uo pipefail
# A guard line starts with its UTC time, 2026-11-27T10:00:00Z, then seat, guard and command. "Since the last patrol" is the snapshot's
# at; with no snapshot, every line counts. No log means no guard has logged: it prints nothing.
[ "${1:-}" != "--help" ] || { sed -n 2,3p "$0"; exit 0; }
# shellcheck source=../record-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../record-lib.sh"
need jq
log=${WHEELHOUSE_GUARD_LOG:-.wheelhouse/guard.log}
[ -f "$log" ] || exit 0
since=""
file=$(rs_patrol_file)
if [ -f "$file" ]; then
  at=$(jq -r '.at // 0' "$file" 2>/dev/null) || die 3 "$file isn't JSON"
  [ "$at" = 0 ] || since=$(date -u -r "$at" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$at" +%Y-%m-%dT%H:%M:%SZ)
fi
while IFS= read -r line; do
  [ -n "$line" ] || continue
  stamp=${line%% *}
  [ -z "$since" ] || [[ "$stamp" > "$since" ]] || continue
  rs_out "$line"
done <"$log"
rs_done
