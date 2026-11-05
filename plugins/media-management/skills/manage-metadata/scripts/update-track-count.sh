#!/usr/bin/env bash
# Set track X/total on all MP3s in a folder, keeping the album's order.
# Usage: update-track-count.sh <folder>
# Output: JSON to stdout
# Exit codes: 0=success, 1=bad args, 2=folder not found, 3=ffmpeg error

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: update-track-count.sh <folder>

Renumber all MP3 files in a folder sequentially and set the track tag to
"X/total". Order is the album's: by the existing track number, then by
filename (so the parts of a split track, which share the original's number,
stay in place, in part order). Files with no track number go last, by
filename. Vendor filenames that do not start with a number therefore keep
their tagged order instead of being renumbered alphabetically.

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

# Sort key per file: existing track number (99999 when absent), then filename.
files=()
while IFS= read -r f; do files+=("$f"); done < <(
  find "$FOLDER" -maxdepth 1 -iname '*.mp3' -type f | sort | while IFS= read -r f; do
    num=$(ffprobe -v quiet -show_entries format_tags=track -of csv=p=0 "$f" 2>/dev/null |
      grep -oE '^[0-9]+' | head -1 || true)
    printf '%05d\t%s\t%s\n' "$((10#${num:-99999}))" "$(basename "$f")" "$f"
  done | LC_ALL=C sort -t "$(printf '\t')" -k1,1n -k2,2 | cut -f3-
)
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
