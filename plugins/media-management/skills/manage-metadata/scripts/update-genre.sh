#!/usr/bin/env bash
# Set genre on all MP3s in a folder.
# Usage: update-genre.sh <folder> <genre>
# Output: JSON to stdout
# Exit codes: 0=success, 1=bad args, 2=folder not found, 3=ffmpeg error

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: update-genre.sh <folder> <genre>

Set the genre tag on all MP3 files in a folder.

Output: JSON to stdout
  {"updated": N, "genre": "..."}
HELP
}

for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
  esac
done

FOLDER="${1:-}"
GENRE="${2:-}"

if [[ -z "$FOLDER" || -z "$GENRE" ]]; then
  echo "Error: folder and genre arguments required" >&2
  exit 1
fi
if [[ ! -d "$FOLDER" ]]; then
  echo "Error: folder not found: $FOLDER" >&2
  exit 2
fi

files=()
while IFS= read -r f; do files+=("$f"); done < <(find "$FOLDER" -maxdepth 1 -iname '*.mp3' -type f | sort)

if [[ ${#files[@]} -eq 0 ]]; then
  jq -n --arg genre "$GENRE" '{"updated": 0, "genre": $genre}'
  exit 0
fi

updated=0
for f in "${files[@]}"; do
  tmp="${f}.tmp.mp3"
  if ffmpeg -v quiet -i "$f" -c copy -map_metadata 0 -metadata "genre=${GENRE}" -y "$tmp" 2>/dev/null; then
    mv "$tmp" "$f"
    ((updated++)) || true
  else
    rm -f "$tmp"
    echo "Warning: failed to update genre for $(basename "$f")" >&2
  fi
done

jq -n --argjson updated "$updated" --arg genre "$GENRE" \
  '{updated: $updated, genre: $genre}'

if [[ $updated -eq 0 && ${#files[@]} -gt 0 ]]; then
  exit 3
fi
