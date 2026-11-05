#!/usr/bin/env bash
# Find ZIPs, loose audio files, and extraction folders related to a music release.
# Usage: find-release-artifacts.sh <downloads_folder> <release_name> [--zip <path>]... [--folder <path>]...
# Output: JSON to stdout with matched artifacts
# Exit codes: 0=success, 1=bad args, 2=folder not found

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: find-release-artifacts.sh <downloads_folder> <release_name> [--zip <path>]... [--folder <path>]...

Find all ZIP files, loose audio files, and extraction folders in the
downloads directory that are related to the given release name.

Name matching (via release_name): the name, minus the extension and a
vendor/browser duplicate suffix (-2, -wav, -flac, -mp3, (1), (pre-order)),
must equal release_name exactly:
  ZIPs:        "Artist - Album.zip", "Artist - Album-2.zip", "Artist - Album (1).zip"
  Audio files: "Artist - Track.mp3", "Artist - Track.wav" (single-track purchases, no ZIP)
  Folders:     "Artist - Album/", "Artist - Album-wav/"
  Not matched: "Artist - Album (Remixes).zip", "Artist - Album-Live/" (other releases)

Explicit paths (--zip / --folder):
  Use these instead of (or alongside) glob matching whenever the caller already
  knows the exact paths — e.g. process-album tracks the original ZIP paths and
  extraction folders it created in earlier steps. This is the reliable path:
  vendor ZIP filenames often do NOT match the clean release_name used for the
  extraction folder (e.g. a Various Artists compilation ZIP named after all 10
  contributing artists, extracted into a folder just called "keep it deep") —
  glob matching alone will miss one side or the other in that case.
  --zip accepts ZIP files or loose audio files (mp3/wav/flac); classified by extension.
  release_name may be an empty string ("") when only explicit paths are given —
  glob matching is then skipped and release_name is used only as a display label.

Arguments:
  downloads_folder  Path to the downloads directory
  release_name      Release name for glob matching (e.g., "Artist - Album"), or ""
  --zip <path>      Explicit ZIP or loose audio file path to include (repeatable)
  --folder <path>   Explicit extraction folder path to include (repeatable)
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
RELEASE_SET=false
explicit_zips=()
explicit_folders=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) show_help; exit 0 ;;
    --zip)
      [[ $# -ge 2 ]] || { echo "Error: --zip requires a path argument" >&2; exit 1; }
      explicit_zips+=("$2")
      shift 2
      ;;
    --folder)
      [[ $# -ge 2 ]] || { echo "Error: --folder requires a path argument" >&2; exit 1; }
      explicit_folders+=("$2")
      shift 2
      ;;
    *)
      if [[ -z "$DOWNLOADS" ]]; then
        DOWNLOADS="$1"
      elif [[ "$RELEASE_SET" == false ]]; then
        RELEASE="$1"
        RELEASE_SET=true
      fi
      shift
      ;;
  esac
done

if [[ -z "$DOWNLOADS" || "$RELEASE_SET" == false ]]; then
  echo "Error: both downloads_folder and release_name arguments required (release_name may be \"\")" >&2
  show_help >&2
  exit 1
fi

if [[ ! -d "$DOWNLOADS" ]]; then
  echo "Error: folder not found: $DOWNLOADS" >&2
  exit 2
fi

# A file or folder belongs to the release when its name, minus the extension
# and the duplicate suffixes vendors and browsers add, is exactly the release
# name. Same rules as select-release's pairing: "-2", "-wav", "-flac", "-mp3",
# " (1)", " (pre-order)". A different release that merely starts with the same
# words ("Artist - Album (Remixes).zip", "Artist - Album-Live/") is not
# matched, so cleanup never archives or deletes it.
same_release() {
  local name="$1"
  name=$(echo "$name" | sed -E 's/\.([zZ][iI][pP]|[mM][pP]3|[wW][aA][vV]|[fF][lL][aA][cC])$//')
  name=$(echo "$name" | sed -E 's/[-_]([0-9]+|wav|WAV|mp3|MP3|flac|FLAC)$//')
  name=$(echo "$name" | sed -E 's/[[:space:]]*\([0-9]+\)$//')
  name=$(echo "$name" | sed -E 's/[[:space:]]*\([pP]re-[oO]rder\)$//')
  [[ "$name" == "$RELEASE" ]]
}

# Find matching ZIP files
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
    if [[ -n "$RELEASE" ]]; then
      for f in "$DOWNLOADS/$RELEASE"*.[zZ][iI][pP]; do
        { [[ -f "$f" ]] && same_release "$(basename "$f")" && echo "$f"; } || true
      done
    fi
    # Explicit paths — validated to exist and be regular files
    for p in "${explicit_zips[@]+"${explicit_zips[@]}"}"; do
      [[ -f "$p" ]] && echo "$p" || echo "Error: --zip path not found: $p" >&2
    done
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
    if [[ -n "$RELEASE" ]]; then
      for f in "$DOWNLOADS/$RELEASE"*; do
        [[ -f "$f" ]] || continue
        case "$(echo "${f##*.}" | tr '[:upper:]' '[:lower:]')" in
          mp3|wav|flac) { same_release "$(basename "$f")" && echo "$f"; } || true ;;
        esac
      done
    fi
    # Explicit --zip paths that are actually loose audio files (mp3/wav/flac), not ZIPs
    for p in "${explicit_zips[@]+"${explicit_zips[@]}"}"; do
      [[ -f "$p" ]] || continue
      case "$(echo "${p##*.}" | tr '[:upper:]' '[:lower:]')" in
        mp3|wav|flac) echo "$p" ;;
      esac
    done
  } | sort -u
)

# Zips array above may have picked up loose audio files passed via --zip; filter those
# back out so a file only appears in one of zips/audio_files, keyed off extension.
zips=$(echo "$zips" | jq '[.[] | select(.file | test("\\.zip$"; "i"))]')

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
    if [[ -n "$RELEASE" ]]; then
      for d in "$DOWNLOADS/$RELEASE"*/; do
        d="${d%/}"
        { [[ -d "$d" ]] && same_release "$(basename "$d")" && echo "$d"; } || true
      done
    fi
    # Explicit paths — validated to exist and be directories
    for p in "${explicit_folders[@]+"${explicit_folders[@]}"}"; do
      [[ -d "$p" ]] && echo "$p" || echo "Error: --folder path not found: $p" >&2
    done
  } | sort -u
)

# Deduplicate by path in case a glob match and an explicit path point to the same file
zips=$(echo "$zips" | jq 'unique_by(.path)')
audio_files=$(echo "$audio_files" | jq 'unique_by(.path)')
folders=$(echo "$folders" | jq 'unique_by(.path)')

jq -n \
  --arg release_name "$RELEASE" \
  --arg downloads_folder "$DOWNLOADS" \
  --argjson zips "$zips" \
  --argjson audio_files "$audio_files" \
  --argjson folders "$folders" \
  '{release_name: $release_name, downloads_folder: $downloads_folder, zips: $zips,
    audio_files: $audio_files, folders: $folders}'
