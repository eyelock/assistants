#!/usr/bin/env bash
# Find music release ZIP files in a downloads folder, classify each, and match into pairs.
# Usage: find-releases.sh <downloads_folder>
# Output: JSON to stdout with matched releases and any unmatched ZIPs
# Exit codes: 0=success, 1=bad args, 2=folder not found

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSPECT_SCRIPT="$SCRIPT_DIR/inspect-zip.sh"

show_help() {
  cat <<'HELP'
Usage: find-releases.sh <downloads_folder>

Find all ZIP files in the downloads folder, inspect each for audio content,
classify as MP3 or WAV, and match into release pairs by base name.

Pairing logic:
  - "Artist - Album.zip" and "Artist - Album-2.zip" → paired
  - "Artist - Album.zip" and "Artist - Album (1).zip" → paired
  - Unpaired ZIPs are listed separately

Output: JSON to stdout
  {
    "releases": [
      {
        "name": "Artist - Album",
        "mp3_zip": {"file": "...", "path": "...", "type": "mp3", "tracks": 8, ...},
        "wav_zip": {"file": "...", "path": "...", "type": "wav", "tracks": 8, ...}
      }
    ],
    "unmatched": [
      {"file": "...", "path": "...", "type": "mp3", "tracks": 5, ...}
    ],
    "total_zips": 4
  }

Exit codes:
  0  Success (even if no ZIPs found — check total_zips)
  1  Bad arguments
  2  Folder not found
HELP
}

DOWNLOADS=""

for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
    *) DOWNLOADS="$arg" ;;
  esac
done

if [[ -z "$DOWNLOADS" ]]; then
  echo "Error: downloads folder argument required" >&2
  show_help >&2
  exit 1
fi

if [[ ! -d "$DOWNLOADS" ]]; then
  echo "Error: folder not found: $DOWNLOADS" >&2
  exit 2
fi

# Find all ZIP files
zip_files=()
while IFS= read -r f; do
  zip_files+=("$f")
done < <(find "$DOWNLOADS" -maxdepth 1 -iname '*.zip' -type f | sort)

if [[ ${#zip_files[@]} -eq 0 ]]; then
  echo '{"releases": [], "unmatched": [], "total_zips": 0}'
  exit 0
fi

# Inspect each ZIP
declare -a inspected_json=()
declare -a inspected_files=()

for zip in "${zip_files[@]}"; do
  result=$("$INSPECT_SCRIPT" "$zip" 2>/dev/null) || continue
  type=$(echo "$result" | jq -r '.type')
  # Only include ZIPs with audio content
  if [[ "$type" != "unknown" ]]; then
    inspected_json+=("$result")
    inspected_files+=("$(basename "$zip")")
  fi
done

if [[ ${#inspected_json[@]} -eq 0 ]]; then
  echo "{\"releases\": [], \"unmatched\": [], \"total_zips\": ${#zip_files[@]}}"
  exit 0
fi

# Extract base names for pairing
# Strips common suffixes: -2, -wav, (1), (2), etc.
normalize_name() {
  local name="$1"
  # Remove .zip extension (case-insensitive)
  name=$(echo "$name" | sed -E 's/\.[zZ][iI][pP]$//')
  # Remove Bandcamp duplicate suffixes: -2, _2, -wav, _wav, etc.
  # REQUIRE the hyphen/underscore separator to avoid stripping album names ending in numbers
  # Must come BEFORE other suffix stripping so e.g. "(pre-order)-2" → "(pre-order)" → stripped
  name=$(echo "$name" | sed -E 's/[-_](2|wav|WAV|flac|FLAC)$//')
  # Remove parenthesized numbers: (1), (2), etc.
  name=$(echo "$name" | sed -E 's/[[:space:]]*\([0-9]+\)$//')
  # Remove known non-numeric suffixes like (pre-order), (bonus), etc.
  name=$(echo "$name" | sed -E 's/[[:space:]]*\(pre-order\)$//i')
  echo "$name"
}

# Build a map of normalized names to their inspected results
# We'll use temporary files since bash associative arrays can be fragile
pair_dir=$(mktemp -d)
trap 'rm -rf "$pair_dir"' EXIT

for i in "${!inspected_json[@]}"; do
  json="${inspected_json[$i]}"
  file=$(echo "$json" | jq -r '.file')
  type=$(echo "$json" | jq -r '.type')
  base=$(normalize_name "$file")

  # Create directory for this base name
  mkdir -p "$pair_dir/$base"

  # Store the JSON keyed by type
  echo "$json" > "$pair_dir/$base/$type.json"
done

# Build output: iterate unique base names
releases="[]"
unmatched="[]"

for base_dir in "$pair_dir"/*/; do
  [[ -d "$base_dir" ]] || continue
  base=$(basename "$base_dir")

  has_mp3=false
  has_wav=false
  mp3_json="null"
  wav_json="null"

  if [[ -f "$base_dir/mp3.json" ]]; then
    has_mp3=true
    mp3_json=$(cat "$base_dir/mp3.json")
  fi
  if [[ -f "$base_dir/wav.json" ]]; then
    has_wav=true
    wav_json=$(cat "$base_dir/wav.json")
  fi
  if [[ -f "$base_dir/flac.json" ]]; then
    # Treat FLAC like WAV for pairing purposes
    has_wav=true
    wav_json=$(cat "$base_dir/flac.json")
  fi

  if $has_mp3 || $has_wav; then
    # Check if this is a pair or a solo
    if $has_mp3 && $has_wav; then
      # Paired release
      release=$(jq -n \
        --arg name "$base" \
        --argjson mp3_zip "$mp3_json" \
        --argjson wav_zip "$wav_json" \
        '{name: $name, mp3_zip: $mp3_zip, wav_zip: $wav_zip}')
      releases=$(echo "$releases" | jq --argjson r "$release" '. + [$r]')
    elif $has_mp3; then
      # Solo MP3
      release=$(jq -n \
        --arg name "$base" \
        --argjson mp3_zip "$mp3_json" \
        '{name: $name, mp3_zip: $mp3_zip, wav_zip: null}')
      releases=$(echo "$releases" | jq --argjson r "$release" '. + [$r]')
    elif $has_wav; then
      # Solo WAV/FLAC
      release=$(jq -n \
        --arg name "$base" \
        --argjson wav_zip "$wav_json" \
        '{name: $name, mp3_zip: null, wav_zip: $wav_zip}')
      releases=$(echo "$releases" | jq --argjson r "$release" '. + [$r]')
    fi
  fi

  # Handle mixed or other types as unmatched
  if [[ -f "$base_dir/mixed.json" ]]; then
    mixed_json=$(cat "$base_dir/mixed.json")
    unmatched=$(echo "$unmatched" | jq --argjson u "$mixed_json" '. + [$u]')
  fi
done

jq -n \
  --argjson releases "$releases" \
  --argjson unmatched "$unmatched" \
  --argjson total_zips "${#zip_files[@]}" \
  '{releases: $releases, unmatched: $unmatched, total_zips: $total_zips}'
