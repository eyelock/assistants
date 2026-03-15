#!/usr/bin/env bash
# Extract a ZIP archive into a named subfolder.
# Usage: extract-zip.sh <zip_file> <dest_folder>
# Output: JSON to stdout with extraction results
# Exit codes: 0=success, 1=bad args, 2=file/folder not found, 3=extraction error

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: extract-zip.sh <zip_file> <dest_folder>

Extract a ZIP archive into a destination subfolder.

Safety: The destination folder MUST be a named subfolder, not the downloads
root itself. The script enforces this by checking that dest_folder has a
non-empty basename that is not a top-level directory.

Arguments:
  zip_file      Path to the ZIP file to extract
  dest_folder   Path to the destination subfolder (created if needed)
  --help        Show this help

Output: JSON to stdout
  {
    "zip_file": "Artist - Album.zip",
    "dest_folder": "/path/to/dest",
    "files_extracted": 10,
    "audio_files": 8,
    "files": ["01 Track.mp3", "02 Track.mp3", ...]
  }

Exit codes:
  0  Success
  1  Bad arguments
  2  ZIP file not found
  3  Extraction error
HELP
}

ZIP_FILE=""
DEST=""

for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
    *)
      if [[ -z "$ZIP_FILE" ]]; then
        ZIP_FILE="$arg"
      elif [[ -z "$DEST" ]]; then
        DEST="$arg"
      fi
      ;;
  esac
done

if [[ -z "$ZIP_FILE" || -z "$DEST" ]]; then
  echo "Error: both zip_file and dest_folder arguments required" >&2
  show_help >&2
  exit 1
fi

if [[ ! -f "$ZIP_FILE" ]]; then
  echo "Error: ZIP file not found: $ZIP_FILE" >&2
  exit 2
fi

# Safety check: dest must be a named subfolder, not a root directory
dest_basename=$(basename "$DEST")
dest_parent=$(dirname "$DEST")

if [[ -z "$dest_basename" || "$dest_basename" == "/" ]]; then
  echo "Error: destination must be a named subfolder, not a root directory" >&2
  exit 1
fi

# Safety check: prevent extracting directly to common top-level dirs
case "$DEST" in
  /|/Users|/Users/*/Downloads|/Users/*/Desktop|/Users/*/Documents)
    echo "Error: refusing to extract directly to $DEST — use a named subfolder" >&2
    exit 1
    ;;
esac

# Create destination
mkdir -p "$DEST" || {
  echo "Error: failed to create destination: $DEST" >&2
  exit 3
}

# Extract
echo "Extracting $(basename "$ZIP_FILE") to $DEST" >&2
if ! unzip -o "$ZIP_FILE" -d "$DEST" >&2 2>&1; then
  echo "Error: extraction failed" >&2
  exit 3
fi

# Count and list extracted files
total_files=0
audio_files=0
file_list="[]"

while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  filename=$(basename "$f")
  total_files=$((total_files + 1))

  # Check if audio
  ext=$(echo "${filename##*.}" | tr '[:upper:]' '[:lower:]')
  case "$ext" in
    mp3|wav|flac|aif|aiff|m4a|ogg)
      audio_files=$((audio_files + 1))
      file_list=$(echo "$file_list" | jq --arg name "$filename" '. + [$name]')
      ;;
  esac
done < <(find "$DEST" -maxdepth 2 -type f | sort)

zip_basename=$(basename "$ZIP_FILE")

jq -n \
  --arg zip_file "$zip_basename" \
  --arg dest_folder "$DEST" \
  --argjson files_extracted "$total_files" \
  --argjson audio_files "$audio_files" \
  --argjson files "$file_list" \
  '{zip_file: $zip_file, dest_folder: $dest_folder, files_extracted: $files_extracted,
    audio_files: $audio_files, files: $files}'
