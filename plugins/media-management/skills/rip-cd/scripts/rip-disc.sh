#!/usr/bin/env bash
# Securely rip every track of the audio CD in the drive to WAV.
# Usage: rip-disc.sh <dest_dir> [--device /dev/diskN] [--offset N] [--tracks 1,2,...]
# Output: JSON to stdout
# Exit codes: 0=every track ripped, 1=bad args, 2=no disc, 3=a track failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
  cat <<'HELP'
Usage: rip-disc.sh <dest_dir> [--device /dev/diskN] [--offset N] [--tracks 1,2,...]

Rip the CD's tracks with cd-paranoia, which rereads any sector until two
reads agree and aborts a track rather than leave a skip in it. Tracks are
written as 01.wav, 02.wav, ... in dest_dir (created if needed); names come
later, from the confirmed release. macOS keeps an audio CD mounted, which
locks the drive, so the disc is unmounted for the rip and mounted again
afterwards, whether or not the rip succeeded.

A full CD takes 15-25 minutes; progress goes to stderr.

Arguments:
  dest_dir          Folder for the WAVs
  --device DEV      Disc device (default: the one `drutil status` reports)
  --offset N        Drive read offset in samples, from config cd_read_offset
                    (default 0). AccurateRip only matches offset-corrected rips
  --tracks LIST     Comma-separated track numbers to rip (default: all)
  --out FILE        Also write the JSON output to FILE
  --help            Show this help

Output: JSON to stdout
  {
    "device": "/dev/disk4", "dest_dir": "/path", "offset": 6,
    "tracks": [{"n": 1, "file": "01.wav", "ok": true, "seconds": 44}, ...],
    "failed": []
  }

Exit codes:
  0  Every track ripped
  1  Bad arguments
  2  No disc in the drive
  3  At least one track could not be read cleanly (see "failed")
HELP
}

# shellcheck source-path=SCRIPTDIR source=lib/out.sh
source "$SCRIPT_DIR/lib/out.sh"
with_out "${BASH_SOURCE[0]}" "$@"

DEST=""
DEVICE=""
OFFSET=0
TRACKS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) show_help; exit 0 ;;
    --device) DEVICE="${2:-}"; shift 2 ;;
    --offset) OFFSET="${2:-}"; shift 2 ;;
    --tracks) TRACKS="${2:-}"; shift 2 ;;
    -*) echo "Error: unknown option: $1" >&2; exit 1 ;;
    *) DEST="$1"; shift ;;
  esac
done

if [[ -z "$DEST" ]]; then
  echo "Error: dest_dir argument required" >&2
  show_help >&2
  exit 1
fi
if ! [[ "$OFFSET" =~ ^-?[0-9]+$ ]]; then
  echo "Error: --offset must be a whole number of samples, got: $OFFSET" >&2
  exit 1
fi

if [[ -z "$DEVICE" ]]; then
  DEVICE=$(drutil status 2>/dev/null | sed -n 's/.*Name: *\(\/dev\/disk[0-9]*\).*/\1/p' | head -1)
fi
if [[ -z "$DEVICE" ]]; then
  echo "Error: no disc in the drive" >&2
  exit 2
fi
RAW="${DEVICE/disk/rdisk}"

mkdir -p "$DEST"

diskutil unmountDisk "$DEVICE" >&2 || true
trap 'diskutil mountDisk "$DEVICE" >&2 || true' EXIT

if ! toc=$(cd-paranoia -d "$RAW" -Q 2>&1); then
  echo "Error: could not read the disc in $DEVICE" >&2
  echo "$toc" | tail -3 >&2
  exit 2
fi
all=$(echo "$toc" | awk '/^ +[0-9]+\./ {sub(/\./, "", $1); print $1}')

if [[ -n "$TRACKS" ]]; then
  wanted=$(echo "$TRACKS" | tr ',' '\n')
else
  wanted="$all"
fi

results="[]"
failed="[]"
for n in $wanted; do
  if ! echo "$all" | grep -qx "$n"; then
    echo "Error: the disc has no track $n" >&2
    exit 1
  fi
  file=$(printf '%02d.wav' "$n")
  echo "Ripping track $n -> $file" >&2
  start=$(date +%s)
  ok=true
  if ! cd-paranoia -d "$RAW" -O "$OFFSET" --never-skip=20 --abort-on-skip -w "$n" "$DEST/$file" >&2; then
    ok=false
    rm -f "$DEST/$file"
    failed=$(echo "$failed" | jq --argjson n "$n" '. + [$n]')
    echo "Error: track $n could not be read cleanly" >&2
  fi
  results=$(echo "$results" | jq --argjson n "$n" --arg file "$file" --argjson ok "$ok" \
    --argjson seconds "$(($(date +%s) - start))" '. + [{n: $n, file: $file, ok: $ok, seconds: $seconds}]')
done

jq -n --arg device "$DEVICE" --arg dest "$DEST" --argjson offset "$OFFSET" \
  --argjson tracks "$results" --argjson failed "$failed" \
  '{device: $device, dest_dir: $dest, offset: $offset, tracks: $tracks, failed: $failed}'

[[ "$(echo "$failed" | jq length)" -eq 0 ]] || exit 3
