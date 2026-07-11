#!/usr/bin/env bash
# Inspect a loose (non-ZIP) audio file and classify it as MP3 or WAV.
# Usage: inspect-audio-file.sh <audio_file>
# Output: JSON to stdout, shaped like inspect-zip.sh's output, for a single track
# Exit codes: 0=success, 1=bad args, 2=file not found

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: inspect-audio-file.sh <audio_file>

Inspect a single loose audio file (not inside a ZIP) and classify it as
MP3/WAV/FLAC by extension. Used to let single-track purchases (Bandcamp
"buy one track" downloads etc.) flow through the same release-matching
pipeline as ZIP-based releases.

Output: JSON to stdout, same shape as inspect-zip.sh but for one track
  {"file": "Artist - Track.mp3", "path": "/full/path/...", "type": "mp3|wav|flac|unknown",
   "tracks": 1, "total_files": 1, "size_bytes": 9500000,
   "audio_extensions": [".mp3"], "source_type": "file"}

Exit codes:
  0  Success
  1  Bad arguments
  2  File not found
HELP
}

AUDIO_FILE=""

for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
    *) AUDIO_FILE="$arg" ;;
  esac
done

if [[ -z "$AUDIO_FILE" ]]; then
  echo "Error: audio file argument required" >&2
  show_help >&2
  exit 1
fi

if [[ ! -f "$AUDIO_FILE" ]]; then
  echo "Error: file not found: $AUDIO_FILE" >&2
  exit 2
fi

filename=$(basename "$AUDIO_FILE")
ext=$(echo "${filename##*.}" | tr '[:upper:]' '[:lower:]')

type="unknown"
ext_json="[]"
case "$ext" in
  mp3) type="mp3"; ext_json='[".mp3"]' ;;
  wav) type="wav"; ext_json='[".wav"]' ;;
  flac) type="flac"; ext_json='[".flac"]' ;;
esac

track_count=0
[[ "$type" != "unknown" ]] && track_count=1

size_bytes=$(stat -f%z "$AUDIO_FILE" 2>/dev/null || stat --printf="%s" "$AUDIO_FILE" 2>/dev/null || echo "0")

jq -n \
  --arg file "$filename" \
  --arg path "$AUDIO_FILE" \
  --arg type "$type" \
  --argjson tracks "$track_count" \
  --argjson size_bytes "$size_bytes" \
  --argjson audio_extensions "$ext_json" \
  '{file: $file, path: $path, type: $type, tracks: $tracks,
    total_files: 1, size_bytes: $size_bytes,
    audio_extensions: $audio_extensions, source_type: "file"}'
