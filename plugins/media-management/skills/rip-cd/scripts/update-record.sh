#!/usr/bin/env bash
# Change one disc's entry in a release record, and the copies of the record
# beside each encoded disc's WAVs.
# Usage: update-record.sh <release.json> --disc N [--accuraterip STATUS] [--discid ID] [--title N=TITLE ...]
# Output: JSON to stdout
# Exit codes: 0=success, 1=bad args, 2=file not found

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: update-record.sh <release.json> --disc N [--accuraterip STATUS] [--discid ID] [--title N=TITLE ...]

Record what was learnt about one disc of the release: its AccurateRip
verdict once verified, its MusicBrainz disc ID once read, or a track title
the user corrected. The record is rewritten in place, and so is every copy
of it in the work folder's disc*/wav/ folders, so whichever disc is archived
next carries the latest record to the NAS.

A title changed here still has to reach Apple Music: run audit-release's
repair-release.sh plan/apply with the record afterwards.

Arguments:
  release.json        The release record
  --disc N            Which audio disc
  --accuraterip S     verified | partial | mismatch | not_in_database
  --discid ID         The disc's MusicBrainz disc ID
  --title N=TITLE     New title for track N; repeatable
  --help              Show this help

Output: JSON to stdout
  {"record": "/path/release.json", "disc": 4, "changed": ["accuraterip", "title 2"],
   "copies_updated": ["/path/disc1/wav/release.json", ...]}

Exit codes:
  0  Success
  1  Bad arguments, or the record has no such disc or track
  2  release.json not found
HELP
}

RECORD=""
DISC=""
VERDICT=""
DISCID=""
TITLES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) show_help; exit 0 ;;
    --disc) DISC="${2:-}"; shift 2 ;;
    --accuraterip) VERDICT="${2:-}"; shift 2 ;;
    --discid) DISCID="${2:-}"; shift 2 ;;
    --title) TITLES+=("${2:-}"); shift 2 ;;
    -*) echo "Error: unknown option: $1" >&2; exit 1 ;;
    *) RECORD="$1"; shift ;;
  esac
done

if [[ -z "$RECORD" || -z "$DISC" ]]; then
  echo "Error: release.json and --disc required" >&2
  show_help >&2
  exit 1
fi
if [[ ! -f "$RECORD" ]]; then
  echo "Error: file not found: $RECORD" >&2
  exit 2
fi
if ! [[ "$DISC" =~ ^[0-9]+$ ]]; then
  echo "Error: --disc must be a number, got: $DISC" >&2
  exit 1
fi
case "$VERDICT" in
  "" | verified | partial | mismatch | not_in_database) ;;
  *) echo "Error: --accuraterip must be verified, partial, mismatch or not_in_database" >&2; exit 1 ;;
esac
if ! jq -e --argjson d "$DISC" 'any(.discs[]; .disc == $d)' "$RECORD" >/dev/null; then
  echo "Error: the record has no disc $DISC" >&2
  exit 1
fi

filter='.'
changed="[]"
if [[ -n "$VERDICT" ]]; then
  filter="$filter | (.discs[] | select(.disc == \$d) | .accuraterip) = \$verdict"
  changed=$(echo "$changed" | jq '. + ["accuraterip"]')
fi
if [[ -n "$DISCID" ]]; then
  filter="$filter | (.discs[] | select(.disc == \$d) | .mb_discid) = \$discid"
  changed=$(echo "$changed" | jq '. + ["mb_discid"]')
fi

titles="{}"
for t in "${TITLES[@]:-}"; do
  [[ -z "$t" ]] && continue
  n="${t%%=*}"
  if ! [[ "$n" =~ ^[0-9]+$ && "$t" == *=* ]]; then
    echo "Error: --title takes N=TITLE, got: $t" >&2
    exit 1
  fi
  if ! jq -e --argjson d "$DISC" --argjson n "$n" \
    'any(.discs[] | select(.disc == $d) | .tracks[]; .n == $n)' "$RECORD" >/dev/null; then
    echo "Error: disc $DISC has no track $n" >&2
    exit 1
  fi
  titles=$(echo "$titles" | jq --arg n "$n" --arg v "${t#*=}" '. + {($n): $v}')
  changed=$(echo "$changed" | jq --arg n "$n" '. + ["title " + $n]')
done
if [[ "$titles" != "{}" ]]; then
  filter="$filter | (.discs[] | select(.disc == \$d) | .tracks[]) |= (if \$titles[(.n | tostring)] then .title = \$titles[(.n | tostring)] else . end)"
fi

TMP="$RECORD.tmp"
jq --argjson d "$DISC" --arg verdict "$VERDICT" --arg discid "$DISCID" --argjson titles "$titles" \
  "$filter" "$RECORD" >"$TMP"
mv "$TMP" "$RECORD"

copies="[]"
work=$(cd "$(dirname "$RECORD")" && pwd)
while IFS= read -r copy; do
  cp "$RECORD" "$copy"
  copies=$(echo "$copies" | jq --arg c "$copy" '. + [$c]')
done < <(find "$work" -mindepth 3 -maxdepth 3 -path '*/wav/release.json' -type f | sort)

jq -n --arg record "$RECORD" --argjson disc "$DISC" --argjson changed "$changed" --argjson copies "$copies" \
  '{record: $record, disc: $disc, changed: $changed, copies_updated: $copies}'
