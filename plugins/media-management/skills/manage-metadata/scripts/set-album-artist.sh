#!/usr/bin/env bash
# Set Album Artist field on all MP3s in a folder.
# Usage: set-album-artist.sh <folder> <artist>
# Output: JSON to stdout
# Exit codes: 0=success, 1=bad args, 2=folder not found, 3=ffmpeg error

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: set-album-artist.sh <folder> <artist>

Set the Album Artist (TPE2) tag on all MP3 files in a folder.

Output: JSON to stdout
  {"updated": N, "album_artist": "..."}
HELP
}

for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
  esac
done

FOLDER="${1:-}"
ARTIST="${2:-}"

if [[ -z "$FOLDER" || -z "$ARTIST" ]]; then
  echo "Error: folder and artist arguments required" >&2
  exit 1
fi
if [[ ! -d "$FOLDER" ]]; then
  echo "Error: folder not found: $FOLDER" >&2
  exit 2
fi

files=()
while IFS= read -r f; do files+=("$f"); done < <(find "$FOLDER" -maxdepth 1 -iname '*.mp3' -type f | sort)

if [[ ${#files[@]} -eq 0 ]]; then
  jq -n --arg artist "$ARTIST" '{"updated": 0, "album_artist": $artist}'
  exit 0
fi

updated=0
for f in "${files[@]}"; do
  tmp="${f}.tmp.mp3"
  if ffmpeg -v quiet -i "$f" -c copy -map_metadata 0 -metadata "album_artist=${ARTIST}" -y "$tmp" 2>/dev/null; then
    mv "$tmp" "$f"
    ((updated++)) || true
  else
    rm -f "$tmp"
    echo "Warning: failed to set album artist for $(basename "$f")" >&2
  fi
done

jq -n --argjson updated "$updated" --arg artist "$ARTIST" \
  '{updated: $updated, album_artist: $artist}'

if [[ $updated -eq 0 && ${#files[@]} -gt 0 ]]; then
  exit 3
fi
