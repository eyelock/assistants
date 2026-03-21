#!/usr/bin/env bash
# Move processed ZIPs to archive and remove extraction folders.
# Usage: cleanup-release.sh <downloads_folder> <release_name>
# Output: JSON to stdout with cleanup results
# Exit codes: 0=success, 1=bad args, 2=folder not found, 3=operation error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIND_SCRIPT="$SCRIPT_DIR/find-release-artifacts.sh"

show_help() {
  cat <<'HELP'
Usage: cleanup-release.sh <downloads_folder> <release_name>

Move processed ZIP files to a "processed/" subfolder and remove extraction
folders for a given release.

This script calls find-release-artifacts.sh to locate items, then:
  - Moves all matching ZIPs to MEDIA_MGMT_PROCESSED (or <downloads_folder>/processed/)
  - Removes all matching extraction folders

Environment:
  MEDIA_MGMT_PROCESSED  Override processed ZIP destination (default: <downloads_folder>/processed/)

Arguments:
  downloads_folder  Path to the downloads directory
  release_name      Release name (e.g., "Artist - Album")
  --help            Show this help

Output: JSON to stdout
  {
    "release_name": "Artist - Album",
    "zips_archived": 2,
    "folders_removed": 2,
    "archived_zips": ["Artist - Album.zip", "Artist - Album-2.zip"],
    "removed_folders": ["Artist - Album", "Artist - Album-wav"]
  }

Exit codes:
  0  Success
  1  Bad arguments
  2  Folder not found
  3  Operation error (some items failed)
HELP
}

DOWNLOADS=""
RELEASE=""

for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
    *)
      if [[ -z "$DOWNLOADS" ]]; then
        DOWNLOADS="$arg"
      elif [[ -z "$RELEASE" ]]; then
        RELEASE="$arg"
      fi
      ;;
  esac
done

if [[ -z "$DOWNLOADS" || -z "$RELEASE" ]]; then
  echo "Error: both downloads_folder and release_name arguments required" >&2
  show_help >&2
  exit 1
fi

if [[ ! -d "$DOWNLOADS" ]]; then
  echo "Error: folder not found: $DOWNLOADS" >&2
  exit 2
fi

# Find artifacts using the companion script
if [[ ! -x "$FIND_SCRIPT" ]]; then
  echo "Error: find-release-artifacts.sh not found at $FIND_SCRIPT" >&2
  exit 3
fi

artifacts=$("$FIND_SCRIPT" "$DOWNLOADS" "$RELEASE") || {
  echo "Error: failed to find release artifacts" >&2
  exit 3
}

# Extract ZIP paths and folder paths
zip_count=$(echo "$artifacts" | jq '.zips | length')
folder_count=$(echo "$artifacts" | jq '.folders | length')

if [[ $zip_count -eq 0 && $folder_count -eq 0 ]]; then
  echo "Nothing to clean up for release: $RELEASE" >&2
  jq -n \
    --arg release_name "$RELEASE" \
    '{release_name: $release_name, zips_archived: 0, folders_removed: 0, archived_zips: [], removed_folders: []}'
  exit 0
fi

# Archive ZIPs
archived_zips="[]"
zips_archived=0
errors=0

# Determine processed destination: env var > config > fallback to $DOWNLOADS/processed
PROCESSED_DIR="${MEDIA_MGMT_PROCESSED:-$DOWNLOADS/processed}"

if [[ $zip_count -gt 0 ]]; then
  mkdir -p "$PROCESSED_DIR" || {
    echo "Error: failed to create processed directory: $PROCESSED_DIR" >&2
    exit 3
  }

  for i in $(seq 0 $((zip_count - 1))); do
    zip_path=$(echo "$artifacts" | jq -r ".zips[$i].path")
    zip_file=$(echo "$artifacts" | jq -r ".zips[$i].file")

    if mv "$zip_path" "$PROCESSED_DIR/" 2>/dev/null; then
      archived_zips=$(echo "$archived_zips" | jq --arg name "$zip_file" '. + [$name]')
      zips_archived=$((zips_archived + 1))
      echo "Archived: $zip_file → $PROCESSED_DIR/" >&2
    else
      echo "Error archiving: $zip_file" >&2
      errors=$((errors + 1))
    fi
  done
fi

# Remove extraction folders
removed_folders="[]"
folders_removed=0

if [[ $folder_count -gt 0 ]]; then
  for i in $(seq 0 $((folder_count - 1))); do
    folder_path=$(echo "$artifacts" | jq -r ".folders[$i].path")
    folder_name=$(echo "$artifacts" | jq -r ".folders[$i].name")

    if rm -rf "$folder_path" 2>/dev/null; then
      removed_folders=$(echo "$removed_folders" | jq --arg name "$folder_name" '. + [$name]')
      folders_removed=$((folders_removed + 1))
      echo "Removed: $folder_name/" >&2
    else
      echo "Error removing: $folder_name/" >&2
      errors=$((errors + 1))
    fi
  done
fi

if [[ $errors -gt 0 ]]; then
  echo "Warning: $errors operation(s) failed" >&2
fi

jq -n \
  --arg release_name "$RELEASE" \
  --argjson zips_archived "$zips_archived" \
  --argjson folders_removed "$folders_removed" \
  --argjson archived_zips "$archived_zips" \
  --argjson removed_folders "$removed_folders" \
  '{release_name: $release_name, zips_archived: $zips_archived, folders_removed: $folders_removed,
    archived_zips: $archived_zips, removed_folders: $removed_folders}'
