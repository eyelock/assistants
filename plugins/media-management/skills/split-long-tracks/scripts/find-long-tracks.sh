#!/usr/bin/env bash
# Find MP3 tracks exceeding a duration threshold.
# Usage: find-long-tracks.sh <folder> [max_minutes]
# Output: JSON to stdout with long tracks and their durations
# Exit codes: 0=success, 1=bad args, 2=folder not found, 3=ffprobe error

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: find-long-tracks.sh <folder> [max_minutes]

Scan all MP3 files in a folder and report any exceeding the duration threshold.

Arguments:
  folder        Path to folder containing MP3 files
  max_minutes   Maximum allowed duration in minutes (default: 78)
  --help        Show this help

Output: JSON to stdout
  {
    "folder": "/path/to/folder",
    "max_minutes": 78,
    "total_tracks": 10,
    "long_tracks": [
      {"file": "01 Track.mp3", "duration_seconds": 5400.5, "duration_display": "90:00"}
    ]
  }

Exit codes:
  0  Success (even if no long tracks found — check long_tracks array)
  1  Bad arguments
  2  Folder not found
  3  ffprobe error
HELP
}

FOLDER=""
MAX_MINUTES=78

for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
    *)
      if [[ -z "$FOLDER" ]]; then
        FOLDER="$arg"
      else
        MAX_MINUTES="$arg"
      fi
      ;;
  esac
done

if [[ -z "$FOLDER" ]]; then
  echo "Error: folder argument required" >&2
  show_help >&2
  exit 1
fi

if [[ ! -d "$FOLDER" ]]; then
  echo "Error: folder not found: $FOLDER" >&2
  exit 2
fi

if ! command -v ffprobe &>/dev/null; then
  echo "Error: ffprobe not found. Install ffmpeg: brew install ffmpeg" >&2
  exit 3
fi

MAX_SECONDS=$(echo "$MAX_MINUTES * 60" | bc)

# Collect MP3 files
files=()
while IFS= read -r f; do files+=("$f"); done < <(find "$FOLDER" -maxdepth 1 -iname '*.mp3' -type f | sort)

total_tracks=${#files[@]}
long_tracks="[]"

for f in "${files[@]}"; do
  duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$f" 2>/dev/null) || {
    echo "Warning: ffprobe failed on $(basename "$f")" >&2
    continue
  }

  # Skip if duration is empty or not a number
  if [[ -z "$duration" ]] || [[ "$duration" == "N/A" ]]; then
    continue
  fi

  # Compare as floating point
  is_long=$(echo "$duration > $MAX_SECONDS" | bc -l 2>/dev/null) || continue
  if [[ "$is_long" -eq 1 ]]; then
    # Format duration as mm:ss
    mins=$(echo "$duration / 60" | bc)
    secs=$(printf "%02d" "$(echo "$duration - ($mins * 60)" | bc | cut -d. -f1)")
    display="${mins}:${secs}"
    filename=$(basename "$f")

    entry=$(jq -n \
      --arg file "$filename" \
      --argjson duration_seconds "$duration" \
      --arg duration_display "$display" \
      '{file: $file, duration_seconds: $duration_seconds, duration_display: $duration_display}')

    long_tracks=$(echo "$long_tracks" | jq --argjson e "$entry" '. + [$e]')
  fi
done

jq -n \
  --arg folder "$FOLDER" \
  --argjson max_minutes "$MAX_MINUTES" \
  --argjson total_tracks "$total_tracks" \
  --argjson long_tracks "$long_tracks" \
  '{folder: $folder, max_minutes: $max_minutes, total_tracks: $total_tracks, long_tracks: $long_tracks}'
