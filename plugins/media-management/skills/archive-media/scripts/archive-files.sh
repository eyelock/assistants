#!/usr/bin/env bash
# Archive audio files (MP3 or WAV) to NAS staging directory.
# Usage: archive-files.sh <mode> <source_dir> <dest_dir>
# Output: JSON to stdout with archive results
# Exit codes: 0=success, 1=bad args, 2=folder not found, 3=copy error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
  cat <<'HELP'
Usage: archive-files.sh <mode> <source_dir> <dest_dir>

Archive audio files to NAS staging directory.

Arguments:
  mode        "mp3" or "wav"
  source_dir  Source folder containing audio files
  dest_dir    Destination folder (will be created if needed)
  --help      Show this help

Behavior by mode:
  mp3: Copies *.mp3 from source to dest, verifies counts
  wav: Copies *.wav from source to dest, runs rename-wav-files.sh, verifies counts

Output: JSON to stdout
  {
    "mode": "mp3",
    "source_dir": "/path/to/source",
    "dest_dir": "/path/to/dest",
    "source_count": 8,
    "dest_count": 8,
    "files": ["01 Track.mp3", ...],
    "renamed": false,
    "verified": true
  }

Exit codes:
  0  Success
  1  Bad arguments
  2  Source folder not found
  3  Copy or rename error
HELP
}

MODE=""
SOURCE=""
DEST=""

for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
    *)
      if [[ -z "$MODE" ]]; then
        MODE="$arg"
      elif [[ -z "$SOURCE" ]]; then
        SOURCE="$arg"
      elif [[ -z "$DEST" ]]; then
        DEST="$arg"
      fi
      ;;
  esac
done

if [[ -z "$MODE" || -z "$SOURCE" || -z "$DEST" ]]; then
  echo "Error: mode, source_dir, and dest_dir arguments required" >&2
  show_help >&2
  exit 1
fi

if [[ "$MODE" != "mp3" && "$MODE" != "wav" ]]; then
  echo "Error: mode must be 'mp3' or 'wav', got: $MODE" >&2
  exit 1
fi

if [[ ! -d "$SOURCE" ]]; then
  echo "Error: source folder not found: $SOURCE" >&2
  exit 2
fi

# Determine file extension to copy
EXT="$MODE"

# Count source files
source_files=()
while IFS= read -r f; do source_files+=("$f"); done < <(find "$SOURCE" -maxdepth 1 -iname "*.$EXT" -type f | sort)

if [[ ${#source_files[@]} -eq 0 ]]; then
  echo "Error: no $EXT files found in $SOURCE" >&2
  exit 1
fi

source_count=${#source_files[@]}
echo "Found $source_count $EXT file(s) in source" >&2

# Create destination
mkdir -p "$DEST" || {
  echo "Error: failed to create destination: $DEST" >&2
  exit 3
}

# Copy files
errors=0
for f in "${source_files[@]}"; do
  filename=$(basename "$f")
  if cp "$f" "$DEST/" 2>/dev/null; then
    echo "Copied: $filename" >&2
  else
    echo "Error copying: $filename" >&2
    errors=$((errors + 1))
  fi
done

if [[ $errors -gt 0 ]]; then
  echo "Error: $errors file(s) failed to copy" >&2
  exit 3
fi

# For WAV mode, rename files using rename-wav-files.sh
renamed=false
if [[ "$MODE" == "wav" ]]; then
  rename_script="$SCRIPT_DIR/rename-wav-files.sh"
  if [[ -x "$rename_script" ]]; then
    echo "Renaming WAV files..." >&2
    if bash "$rename_script" "$DEST"; then
      renamed=true
      echo "Rename complete" >&2
    else
      echo "Warning: rename script failed, files copied but not renamed" >&2
    fi
  else
    echo "Warning: rename-wav-files.sh not found at $rename_script" >&2
  fi
fi

# Count destination files and build file list
dest_files=()
while IFS= read -r f; do dest_files+=("$f"); done < <(find "$DEST" -maxdepth 1 -iname "*.$EXT" -type f | sort)

dest_count=${#dest_files[@]}

# Build file list JSON
file_list="[]"
for f in "${dest_files[@]}"; do
  filename=$(basename "$f")
  file_list=$(echo "$file_list" | jq --arg name "$filename" '. + [$name]')
done

# Verify counts match
verified=false
if [[ $source_count -eq $dest_count ]]; then
  verified=true
  echo "Verified: $source_count source = $dest_count destination" >&2
else
  echo "Warning: count mismatch — source=$source_count, destination=$dest_count" >&2
fi

jq -n \
  --arg mode "$MODE" \
  --arg source_dir "$SOURCE" \
  --arg dest_dir "$DEST" \
  --argjson source_count "$source_count" \
  --argjson dest_count "$dest_count" \
  --argjson files "$file_list" \
  --argjson renamed "$renamed" \
  --argjson verified "$verified" \
  '{mode: $mode, source_dir: $source_dir, dest_dir: $dest_dir,
    source_count: $source_count, dest_count: $dest_count,
    files: $files, renamed: $renamed, verified: $verified}'
