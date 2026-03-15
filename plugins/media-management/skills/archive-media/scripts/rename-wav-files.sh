#!/usr/bin/env bash
# Rename WAV files to clean "01 Title.wav" format.
# Usage: rename-wav-files.sh <folder>
# Output: JSON to stdout
# Exit codes: 0=success, 1=bad args, 2=folder not found

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: rename-wav-files.sh <folder>

Rename WAV files from vendor format (e.g., "Artist - Album - 01 Title.wav")
to clean format ("01 Title.wav"). Extracts track number and title from
the filename or falls back to metadata via ffprobe.

Files that don't match any known pattern are skipped with a warning.

Output: JSON to stdout
  {"renamed": [{"from": "...", "to": "..."}], "skipped": [...]}
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
while IFS= read -r f; do files+=("$f"); done < <(find "$FOLDER" -maxdepth 1 -iname '*.wav' -type f | sort)

if [[ ${#files[@]} -eq 0 ]]; then
  echo '{"renamed": [], "skipped": []}'
  exit 0
fi

renamed_json="[]"
skipped_json="[]"

for f in "${files[@]}"; do
  filename=$(basename "$f")

  # Pattern 1: "Artist - Album - 01 Title.wav" or "Artist - Album - 1 Title.wav"
  if [[ "$filename" =~ ^.+\ -\ .+\ -\ ([0-9]+)\ (.+)\.wav$ ]]; then
    track_num=$(printf "%02d" "${BASH_REMATCH[1]}")
    title="${BASH_REMATCH[2]}"
    new_name="${track_num} ${title}.wav"
  # Pattern 2: "01 Title.wav" or "1 Title.wav" (already close to target)
  elif [[ "$filename" =~ ^([0-9]+)\ (.+)\.wav$ ]]; then
    track_num=$(printf "%02d" "${BASH_REMATCH[1]}")
    title="${BASH_REMATCH[2]}"
    new_name="${track_num} ${title}.wav"
  # Pattern 3: "01. Title.wav" or "01 - Title.wav"
  elif [[ "$filename" =~ ^([0-9]+)[.\ -]+(.+)\.wav$ ]]; then
    track_num=$(printf "%02d" "${BASH_REMATCH[1]}")
    title="${BASH_REMATCH[2]}"
    new_name="${track_num} ${title}.wav"
  else
    # Try metadata fallback
    meta=$(ffprobe -v quiet -print_format json -show_format "$f" 2>/dev/null || echo '{}')
    track=$(echo "$meta" | jq -r '.format.tags.track // .format.tags.TRACK // ""' | grep -oE '[0-9]+' | head -1)
    title=$(echo "$meta" | jq -r '.format.tags.title // .format.tags.TITLE // ""')

    if [[ -n "$track" && -n "$title" ]]; then
      track_num=$(printf "%02d" "$track")
      new_name="${track_num} ${title}.wav"
    else
      skipped_json=$(echo "$skipped_json" | jq --arg file "$filename" '. + [$file]')
      echo "Warning: skipping unrecognized format: $filename" >&2
      continue
    fi
  fi

  # Only rename if the name actually changes
  if [[ "$filename" != "$new_name" ]]; then
    # Guard against overwriting an existing file
    if [[ -e "${FOLDER}/${new_name}" ]]; then
      skipped_json=$(echo "$skipped_json" | jq --arg file "$filename" '. + [$file]')
      echo "Warning: skipping rename — target already exists: $new_name" >&2
      continue
    fi
    mv "$f" "${FOLDER}/${new_name}"
    renamed_json=$(echo "$renamed_json" | jq \
      --arg from "$filename" --arg to "$new_name" \
      '. + [{"from": $from, "to": $to}]')
  fi
done

jq -n --argjson renamed "$renamed_json" --argjson skipped "$skipped_json" \
  '{renamed: $renamed, skipped: $skipped}'
