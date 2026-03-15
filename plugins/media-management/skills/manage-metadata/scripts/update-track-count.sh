#!/usr/bin/env bash
# Set track X/total on all MP3s in a folder (sorted alphabetically).
# Usage: update-track-count.sh <folder>
# Output: JSON to stdout
# Exit codes: 0=success, 1=bad args, 2=folder not found, 3=ffmpeg error

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: update-track-count.sh <folder>

Renumber all MP3 files in a folder sequentially (sorted alphabetically).
Sets track tag to "X/total" format.

Output: JSON to stdout
  {"updated": N, "total": N}
HELP
}

for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
  esac
done

FOLDER="${1:-}"
if [[ -z "$FOLDER" ]]; then
  echo "Error: folder argument required" >&2
  exit 1
fi
if [[ ! -d "$FOLDER" ]]; then
  echo "Error: folder not found: $FOLDER" >&2
  exit 2
fi

files=()
while IFS= read -r f; do files+=("$f"); done < <(find "$FOLDER" -maxdepth 1 -iname '*.mp3' -type f | sort)
total=${#files[@]}

if [[ $total -eq 0 ]]; then
  echo '{"updated": 0, "total": 0}'
  exit 0
fi

updated=0
for i in "${!files[@]}"; do
  f="${files[$i]}"
  track_num=$((i + 1))
  tmp="${f}.tmp.mp3"

  if ffmpeg -v quiet -i "$f" -c copy -map_metadata 0 -metadata "track=${track_num}/${total}" -y "$tmp" 2>/dev/null; then
    mv "$tmp" "$f"
    ((updated++)) || true
  else
    rm -f "$tmp"
    echo "Warning: failed to update track count for $(basename "$f")" >&2
  fi
done

jq -n --argjson updated "$updated" --argjson total "$total" \
  '{updated: $updated, total: $total}'

if [[ $updated -eq 0 && $total -gt 0 ]]; then
  exit 3
fi
