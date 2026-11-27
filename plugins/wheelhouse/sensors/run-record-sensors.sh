#!/usr/bin/env bash
# Runs the record sensors (sensors/record/*.sh) in a Wheelhouse and keeps their counts, so the patrol can say which rose and the
# desk's wake can show the ones above zero.
#
# Each sensor prints one line per item and exits 1 when there is any; its count is its number of lines. Exit 0 is a count of 0; any
# other exit (3: could not read what it counts) is an error, kept apart from a zero. The counts go to the results file, beside the
# patrol's snapshot:
#
#   {"at": <epoch seconds>, "interval_minutes": <n>,
#    "sensors": {"<name>": {"count": <n>|null, "previous": <n>|null, "rose": <bool>, "lines": [...], "error": "<why>"}}}
#
# A record sensor has no ratchet (ynh's baseline is a committed file): the finding is a count that rose since this script's last
# run, read from the previous results file. A sensor that errored keeps its last known count as "previous", so one bad read neither
# clears a finding nor makes the next run's count look like a rise. The first run has nothing to compare with: nothing rose.
#
# Prints a JSON list of the sensors that rose: {kind: "record-sensor-rose", sensor, from, to, lines}. [] when none did.
# Needs bash and jq, and the tools each sensor names (bd, gh); not ynh.
set -uo pipefail

usage() { echo "Usage: run-record-sensors.sh [--dir <wheelhouse repo>] [--out <results file>] [--interval <patrol minutes>] [--patrol-file <snapshot>]"; }

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
for lib in "$here/../skills/work-graph/scripts/wheelhouse-lib.sh" "$here/wheelhouse-lib.sh"; do
  # shellcheck source=../skills/work-graph/scripts/wheelhouse-lib.sh
  [ -f "$lib" ] && { . "$lib"; break; }
done
type wl_loaded >/dev/null 2>&1 || { echo "wheelhouse-lib.sh not found: it is in the work-graph skill's scripts folder" >&2; exit 3; }
# shellcheck disable=SC2034  # read by the library
WL_PREFIX="run-record-sensors: "

dir="."; out=""; interval=5; patrol=""
while [ $# -gt 0 ]; do
  case "$1" in
    --help | -h) usage; exit 0 ;;
    --dir | --out | --interval | --patrol-file)
      [ $# -ge 2 ] || { usage >&2; exit 1; }
      case "$1" in --dir) dir="$2" ;; --out) out="$2" ;; --interval) interval="$2" ;; --patrol-file) patrol="$2" ;; esac
      shift 2 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done
[[ "$interval" =~ ^[1-9][0-9]*$ ]] || die 1 "--interval must be a positive number of minutes"
need jq
[ -d "$dir" ] || die 2 "no folder $dir"
cd "$dir" || exit 2
[ -n "$out" ] || out=.wheelhouse/record-sensors.json
[ -n "$patrol" ] || patrol=.wheelhouse/patrol.json
export WHEELHOUSE_PATROL_FILE="$patrol"
mkdir -p "$(dirname "$out")" || die 3 "could not make the folder for $out"

old='{}'
if [ -f "$out" ]; then
  old=$(jq -c '.sensors // {}' "$out" 2>/dev/null) || die 3 "$out isn't JSON: move it aside to start again"
fi

results='{}'
for script in "$here"/record/*.sh; do
  [ -f "$script" ] || continue
  name=$(basename "$script" .sh)
  lines=$(limited "${WL_RECORD_SENSOR_SECS:-120}" bash "$script" 2>"$out.err"); rc=$?
  err=$(head -1 "$out.err")
  prev=$(jq -c --arg n "$name" '.[$n] | (.count // .previous) // null' <<<"$old")
  case "$rc" in
    0 | 1)
      count=$(grep -c . <<<"$lines" || true)
      [ "$rc" = 1 ] || count=0
      [ "$rc" = 0 ] || [ "$count" -gt 0 ] || count=1
      results=$(jq -c --arg n "$name" --argjson c "$count" --argjson p "$prev" --arg l "$lines" \
        '. + {($n): {count: $c, previous: $p, rose: ($p != null and $c > $p), lines: ($l | split("\n") | map(select(length > 0)) | .[:50])}}' <<<"$results") ;;
    *)
      # Could not read: no count. The last known one stays as "previous" so it is not lost.
      msg=${err:-exited $rc}; [ "$rc" != 142 ] || msg="gave up after ${WL_RECORD_SENSOR_SECS:-120} seconds"
      results=$(jq -c --arg n "$name" --argjson p "$prev" --arg e "$msg" \
        '. + {($n): {count: null, previous: $p, rose: false, lines: [], error: $e}}' <<<"$results") ;;
  esac
done
rm -f "$out.err"

jq -nc --argjson s "$results" --argjson at "$(date +%s)" --argjson i "$interval" \
  '{at: $at, interval_minutes: $i, sensors: $s}' >"$out.new" || die 3 "could not write $out"
mv "$out.new" "$out" || die 3 "could not write $out"

jq -c '[.sensors | to_entries[] | select(.value.rose) | {kind: "record-sensor-rose", sensor: .key, from: .value.previous, to: .value.count, lines: .value.lines}]' "$out"
