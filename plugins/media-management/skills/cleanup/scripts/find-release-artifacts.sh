#!/usr/bin/env bash
# Find ZIP files and extraction folders related to a music release.
# Usage: find-release-artifacts.sh <downloads_folder> <release_name>
# Output: JSON to stdout with matched artifacts
# Exit codes: 0=success, 1=bad args, 2=folder not found

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: find-release-artifacts.sh <downloads_folder> <release_name>

Find all ZIP files and extraction folders in the downloads directory that
are related to the given release name.

Matches:
  ZIPs:    "Artist - Album.zip", "Artist - Album-2.zip", "Artist - Album (1).zip"
  Folders: "Artist - Album/", "Artist - Album-wav/"

Arguments:
  downloads_folder  Path to the downloads directory
  release_name      Release name (e.g., "Artist - Album")
  --help            Show this help

Output: JSON to stdout
  {
    "release_name": "Artist - Album",
    "downloads_folder": "/path/to/downloads",
    "zips": [
      {"file": "Artist - Album.zip", "path": "/full/path/...", "size_bytes": 95000000}
    ],
    "folders": [
      {"name": "Artist - Album", "path": "/full/path/..."}
    ]
  }

Exit codes:
  0  Success (even if nothing found — check arrays)
  1  Bad arguments
  2  Folder not found
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

# Find matching ZIP files
# Match patterns: exact name, -2 suffix, -wav suffix, (N) suffix, (pre-order) suffix
zips="[]"
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  filename=$(basename "$f")
  size_bytes=$(stat -f%z "$f" 2>/dev/null || stat --printf="%s" "$f" 2>/dev/null || echo "0")

  entry=$(jq -n \
    --arg file "$filename" \
    --arg path "$f" \
    --argjson size_bytes "$size_bytes" \
    '{file: $file, path: $path, size_bytes: $size_bytes}')

  zips=$(echo "$zips" | jq --argjson e "$entry" '. + [$e]')
done < <(
  {
    # Exact match
    ls "$DOWNLOADS/$RELEASE.zip" 2>/dev/null
    # Bandcamp suffixes: -2, -wav, etc.
    ls "$DOWNLOADS/$RELEASE-"*.zip 2>/dev/null
    # Parenthesized suffixes: (1), (pre-order), etc.
    ls "$DOWNLOADS/$RELEASE ("*.zip 2>/dev/null
  } | sort -u
)

# Find matching extraction folders
folders="[]"
while IFS= read -r d; do
  [[ -d "$d" ]] || continue
  dirname=$(basename "$d")

  entry=$(jq -n \
    --arg name "$dirname" \
    --arg path "$d" \
    '{name: $name, path: $path}')

  folders=$(echo "$folders" | jq --argjson e "$entry" '. + [$e]')
done < <(
  {
    # Exact match folder
    [[ -d "$DOWNLOADS/$RELEASE" ]] && echo "$DOWNLOADS/$RELEASE"
    # WAV extraction folder
    [[ -d "$DOWNLOADS/$RELEASE-wav" ]] && echo "$DOWNLOADS/$RELEASE-wav"
    # Other variant folders
    for d in "$DOWNLOADS/$RELEASE-"*/; do
      [[ -d "$d" ]] && echo "${d%/}"
    done
  } | sort -u
)

jq -n \
  --arg release_name "$RELEASE" \
  --arg downloads_folder "$DOWNLOADS" \
  --argjson zips "$zips" \
  --argjson folders "$folders" \
  '{release_name: $release_name, downloads_folder: $downloads_folder, zips: $zips, folders: $folders}'
