#!/usr/bin/env bash
# Find ZIPs, loose audio files, and extraction folders related to a music release.
# Usage: find-release-artifacts.sh <downloads_folder> <release_name>
# Output: JSON to stdout with matched artifacts
# Exit codes: 0=success, 1=bad args, 2=folder not found

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: find-release-artifacts.sh <downloads_folder> <release_name>

Find all ZIP files, loose audio files, and extraction folders in the
downloads directory that are related to the given release name.

Matches:
  ZIPs:        "Artist - Album.zip", "Artist - Album-2.zip", "Artist - Album (1).zip"
  Audio files: "Artist - Track.mp3", "Artist - Track.wav" (single-track purchases, no ZIP)
  Folders:     "Artist - Album/", "Artist - Album-wav/"

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
    "audio_files": [
      {"file": "Artist - Track.mp3", "path": "/full/path/...", "size_bytes": 9500000}
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
    # `|| true` on every glob attempt: under `set -e`, a non-matching glob
    # makes `ls` exit non-zero, which kills this process-substitution
    # subshell immediately and silently drops every pattern tried after it.
    ls "$DOWNLOADS/$RELEASE.zip" 2>/dev/null || true
    # Bandcamp suffixes: -2, -wav, etc.
    ls "$DOWNLOADS/$RELEASE-"*.zip 2>/dev/null || true
    # Parenthesized suffixes: (1), (pre-order), etc.
    ls "$DOWNLOADS/$RELEASE ("*.zip 2>/dev/null || true
  } | sort -u
)

# Find matching loose audio files (single-track purchases with no ZIP)
audio_files="[]"
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  filename=$(basename "$f")
  size_bytes=$(stat -f%z "$f" 2>/dev/null || stat --printf="%s" "$f" 2>/dev/null || echo "0")

  entry=$(jq -n \
    --arg file "$filename" \
    --arg path "$f" \
    --argjson size_bytes "$size_bytes" \
    '{file: $file, path: $path, size_bytes: $size_bytes}')

  audio_files=$(echo "$audio_files" | jq --argjson e "$entry" '. + [$e]')
done < <(
  {
    for ext in mp3 wav flac; do
      ls "$DOWNLOADS/$RELEASE.$ext" 2>/dev/null || true
      ls "$DOWNLOADS/$RELEASE-"*".$ext" 2>/dev/null || true
      ls "$DOWNLOADS/$RELEASE ("*").$ext" 2>/dev/null || true
    done
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
    # Same `|| true` reasoning as the ZIP/audio-file globs above: under
    # `set -e`, a false `[[ -d ]] && echo` (folder doesn't exist) exits
    # non-zero and kills this subshell before later checks run.
    # Exact match folder
    { [[ -d "$DOWNLOADS/$RELEASE" ]] && echo "$DOWNLOADS/$RELEASE"; } || true
    # WAV extraction folder
    { [[ -d "$DOWNLOADS/$RELEASE-wav" ]] && echo "$DOWNLOADS/$RELEASE-wav"; } || true
    # Other variant folders
    for d in "$DOWNLOADS/$RELEASE-"*/; do
      { [[ -d "$d" ]] && echo "${d%/}"; } || true
    done
  } | sort -u
)

jq -n \
  --arg release_name "$RELEASE" \
  --arg downloads_folder "$DOWNLOADS" \
  --argjson zips "$zips" \
  --argjson audio_files "$audio_files" \
  --argjson folders "$folders" \
  '{release_name: $release_name, downloads_folder: $downloads_folder, zips: $zips,
    audio_files: $audio_files, folders: $folders}'
