#!/usr/bin/env bash
# Inspect a ZIP file and classify its contents as MP3 or WAV.
# Usage: inspect-zip.sh <zip_file>
# Output: JSON to stdout with file type, track count, and size details
# Exit codes: 0=success, 1=bad args, 2=file not found

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: inspect-zip.sh <zip_file>

Inspect a ZIP archive and classify its audio contents as MP3 or WAV.

Classification is based on file extensions inside the archive, NOT the
ZIP filename. Size is also reported for cross-validation.

Output: JSON to stdout
  {"file": "Artist - Album.zip", "path": "/full/path/...", "type": "mp3|wav|mixed|unknown",
   "tracks": 8, "total_files": 10, "size_bytes": 95000000,
   "audio_extensions": [".mp3"]}

Exit codes:
  0  Success
  1  Bad arguments
  2  File not found
HELP
}

ZIP_FILE=""

for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
    *) ZIP_FILE="$arg" ;;
  esac
done

if [[ -z "$ZIP_FILE" ]]; then
  echo "Error: zip file argument required" >&2
  show_help >&2
  exit 1
fi

if [[ ! -f "$ZIP_FILE" ]]; then
  echo "Error: file not found: $ZIP_FILE" >&2
  exit 2
fi

# Get listing from unzip -l
listing=$(unzip -l "$ZIP_FILE" 2>/dev/null) || {
  echo "Error: failed to read zip: $ZIP_FILE" >&2
  exit 2
}

# Count audio files by extension (case-insensitive)
mp3_count=0
wav_count=0
flac_count=0
other_audio=0
total_files=0
extensions=()

while IFS= read -r line; do
  # unzip -l lines with files have the format: <size> <date> <time> <name>
  # Skip header/footer lines - file lines start with whitespace then a number
  if [[ "$line" =~ ^[[:space:]]*[0-9]+[[:space:]] ]]; then
    # Extract filename (last field after the date/time)
    fname=$(echo "$line" | awk '{for(i=4;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ *$//')

    # Skip directory entries (end with /)
    [[ "$fname" == */ ]] && continue

    total_files=$((total_files + 1))

    # Get extension (lowercase)
    ext=$(echo "${fname##*.}" | tr '[:upper:]' '[:lower:]')

    case "$ext" in
      mp3) mp3_count=$((mp3_count + 1)) ;;
      wav) wav_count=$((wav_count + 1)) ;;
      flac) flac_count=$((flac_count + 1)) ;;
      aif|aiff|m4a|ogg) other_audio=$((other_audio + 1)) ;;
    esac
  fi
done <<< "$listing"

# Determine type based on audio file counts
track_count=0
type="unknown"
if [[ $mp3_count -gt 0 && $wav_count -eq 0 ]]; then
  type="mp3"
  track_count=$mp3_count
elif [[ $wav_count -gt 0 && $mp3_count -eq 0 ]]; then
  type="wav"
  track_count=$wav_count
elif [[ $flac_count -gt 0 && $mp3_count -eq 0 && $wav_count -eq 0 ]]; then
  type="flac"
  track_count=$flac_count
elif [[ $mp3_count -gt 0 && $wav_count -gt 0 ]]; then
  type="mixed"
  track_count=$((mp3_count + wav_count))
fi

# Build extensions array for JSON
ext_json="[]"
if [[ $mp3_count -gt 0 ]]; then ext_json=$(echo "$ext_json" | jq '. + [".mp3"]'); fi
if [[ $wav_count -gt 0 ]]; then ext_json=$(echo "$ext_json" | jq '. + [".wav"]'); fi
if [[ $flac_count -gt 0 ]]; then ext_json=$(echo "$ext_json" | jq '. + [".flac"]'); fi

# Get ZIP file size in bytes
size_bytes=$(stat -f%z "$ZIP_FILE" 2>/dev/null || stat --printf="%s" "$ZIP_FILE" 2>/dev/null || echo "0")

filename=$(basename "$ZIP_FILE")

jq -n \
  --arg file "$filename" \
  --arg path "$ZIP_FILE" \
  --arg type "$type" \
  --argjson tracks "$track_count" \
  --argjson total_files "$total_files" \
  --argjson size_bytes "$size_bytes" \
  --argjson audio_extensions "$ext_json" \
  '{file: $file, path: $path, type: $type, tracks: $tracks,
    total_files: $total_files, size_bytes: $size_bytes,
    audio_extensions: $audio_extensions}'
