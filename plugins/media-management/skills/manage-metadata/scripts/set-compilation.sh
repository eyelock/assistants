#!/usr/bin/env bash
# Set compilation flag (and optionally Album Artist) on all MP3s in a folder.
# Usage: set-compilation.sh <folder> [true|false]
# Output: JSON to stdout
# Exit codes: 0=success, 1=bad args, 2=folder not found, 3=ffmpeg error

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: set-compilation.sh <folder> [true|false]

Set the compilation flag (TCMP) on all MP3 files in a folder.
When true, also sets Album Artist to "Various Artists".
When false, clears the compilation flag and Album Artist.

Default: true

Output: JSON to stdout
  {"updated": N, "compilation": true|false}
HELP
}

for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
  esac
done

FOLDER="${1:-}"
COMP_FLAG="${2:-true}"

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

if [[ ${#files[@]} -eq 0 ]]; then
  if [[ "$COMP_FLAG" == "true" ]]; then
    echo '{"updated": 0, "compilation": true}'
  else
    echo '{"updated": 0, "compilation": false}'
  fi
  exit 0
fi

updated=0
for f in "${files[@]}"; do
  tmp="${f}.tmp.mp3"
  if [[ "$COMP_FLAG" == "true" ]]; then
    # Set compilation=1 and Album Artist to Various Artists in one pass
    if ffmpeg -v quiet -i "$f" -c copy -map_metadata 0 \
        -metadata "compilation=1" -metadata "album_artist=Various Artists" \
        -y "$tmp" 2>/dev/null; then
      mv "$tmp" "$f"
      ((updated++)) || true
    else
      rm -f "$tmp"
      echo "Warning: failed to set compilation for $(basename "$f")" >&2
    fi
  else
    # Clear compilation flag and Album Artist
    if ffmpeg -v quiet -i "$f" -c copy -map_metadata 0 \
        -metadata "compilation=0" -metadata "album_artist=" \
        -y "$tmp" 2>/dev/null; then
      mv "$tmp" "$f"
      ((updated++)) || true
    else
      rm -f "$tmp"
      echo "Warning: failed to clear compilation for $(basename "$f")" >&2
    fi
  fi
done

if [[ "$COMP_FLAG" == "true" ]]; then
  jq -n --argjson updated "$updated" '{updated: $updated, compilation: true}'
else
  jq -n --argjson updated "$updated" '{updated: $updated, compilation: false}'
fi

if [[ $updated -eq 0 && ${#files[@]} -gt 0 ]]; then
  exit 3
fi
