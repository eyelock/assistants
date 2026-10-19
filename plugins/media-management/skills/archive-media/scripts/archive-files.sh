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
  mp3: Copies *.mp3 from source to dest
  wav: Renames *.wav from source with rename-wav-files.sh in a staging
       folder, then copies them to dest, with release.json and cover.jpg
       when the source has them (a CD rip)

  "verified" is true when every source file is in dest at the same size.
  dest may hold more files than source: another disc of the same release
  archived to the same folder earlier. dest_count counts them all.

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

# WAVs are renamed in a staging folder first, so what reaches the NAS is
# already clean and can be checked file by file against what was staged.
STAGE="$SOURCE"
renamed=false
if [[ "$MODE" == "wav" ]]; then
  STAGE=$(mktemp -d "${TMPDIR:-/tmp}/archive-wav.XXXXXX")
  trap 'rm -rf "$STAGE"' EXIT
  for f in "${source_files[@]}"; do
    cp "$f" "$STAGE/" || { echo "Error staging: $(basename "$f")" >&2; exit 3; }
  done
  rename_script="$SCRIPT_DIR/rename-wav-files.sh"
  if [[ -x "$rename_script" ]]; then
    echo "Renaming WAV files..." >&2
    # Its JSON goes to stderr: this script prints exactly one JSON document.
    if bash "$rename_script" "$STAGE" >&2; then
      renamed=true
      echo "Rename complete" >&2
    else
      echo "Warning: rename script failed, files copied but not renamed" >&2
    fi
  else
    echo "Warning: rename-wav-files.sh not found at $rename_script" >&2
  fi
fi

staged=()
while IFS= read -r f; do staged+=("$f"); done < <(find "$STAGE" -maxdepth 1 -iname "*.$EXT" -type f | sort)

# Copy files
errors=0
for f in "${staged[@]}"; do
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

# A CD rip's release record and cover travel with its WAVs, so a later disc
# of the same release can reuse the answers given for this one.
if [[ "$MODE" == "wav" ]]; then
  for extra in release.json cover.jpg; do
    if [[ -f "$SOURCE/$extra" ]]; then
      cp "$SOURCE/$extra" "$DEST/$extra" && echo "Copied: $extra" >&2
    fi
  done
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

# Verify every staged file arrived at the same size. The destination may hold
# more: an earlier disc of the same release archived to the same folder.
verified=true
for f in "${staged[@]}"; do
  target="$DEST/$(basename "$f")"
  if [[ ! -f "$target" ]] || [[ $(wc -c <"$f") -ne $(wc -c <"$target") ]]; then
    verified=false
    echo "Warning: not archived intact: $(basename "$f")" >&2
  fi
done
if [[ "$verified" == true ]]; then
  echo "Verified: all $source_count file(s) in the destination ($dest_count there in all)" >&2
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
