#!/usr/bin/env bash
# Copy a loose (non-ZIP) audio file into a named subfolder, mirroring the
# safety checks and output shape of extract-zip.sh so downstream steps can
# treat ZIP-based and single-file releases identically.
# Usage: copy-file.sh <audio_file> <dest_folder>
# Output: JSON to stdout with copy results
# Exit codes: 0=success, 1=bad args, 2=file/folder not found, 3=copy error

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: copy-file.sh <audio_file> <dest_folder>

Copy a single loose audio file (a single-track purchase with no ZIP) into
a destination subfolder, so it can go through the same metadata/import/
archive pipeline as an extracted ZIP release.

Safety: The destination folder MUST be a named subfolder, not the downloads
root itself. Same rule as extract-zip.sh.

Arguments:
  audio_file    Path to the audio file to copy
  dest_folder   Path to the destination subfolder (created if needed)
  --help        Show this help

Output: JSON to stdout
  {
    "source_file": "Artist - Track.mp3",
    "dest_folder": "/path/to/dest",
    "files_extracted": 1,
    "audio_files": 1,
    "files": ["Artist - Track.mp3"]
  }

Exit codes:
  0  Success
  1  Bad arguments
  2  Audio file not found
  3  Copy error
HELP
}

AUDIO_FILE=""
DEST=""

for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
    *)
      if [[ -z "$AUDIO_FILE" ]]; then
        AUDIO_FILE="$arg"
      elif [[ -z "$DEST" ]]; then
        DEST="$arg"
      fi
      ;;
  esac
done

if [[ -z "$AUDIO_FILE" || -z "$DEST" ]]; then
  echo "Error: both audio_file and dest_folder arguments required" >&2
  show_help >&2
  exit 1
fi

if [[ ! -f "$AUDIO_FILE" ]]; then
  echo "Error: audio file not found: $AUDIO_FILE" >&2
  exit 2
fi

# Safety check: dest must be a named subfolder, not a root directory
dest_basename=$(basename "$DEST")

if [[ -z "$dest_basename" || "$dest_basename" == "/" ]]; then
  echo "Error: destination must be a named subfolder, not a root directory" >&2
  exit 1
fi

# Safety check: prevent copying directly to common top-level dirs
case "$DEST" in
  /|/Users|/Users/*/Downloads|/Users/*/Desktop|/Users/*/Documents)
    echo "Error: refusing to copy directly to $DEST — use a named subfolder" >&2
    exit 1
    ;;
esac

# Create destination
mkdir -p "$DEST" || {
  echo "Error: failed to create destination: $DEST" >&2
  exit 3
}

filename=$(basename "$AUDIO_FILE")

echo "Copying $filename to $DEST" >&2
if ! cp "$AUDIO_FILE" "$DEST/$filename" >&2 2>&1; then
  echo "Error: copy failed" >&2
  exit 3
fi

jq -n \
  --arg source_file "$filename" \
  --arg dest_folder "$DEST" \
  --arg name "$filename" \
  '{source_file: $source_file, dest_folder: $dest_folder, files_extracted: 1,
    audio_files: 1, files: [$name]}'
