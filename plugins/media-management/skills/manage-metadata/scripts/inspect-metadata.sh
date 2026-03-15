#!/usr/bin/env bash
# Inspect MP3 metadata for all files in a folder.
# Usage: inspect-metadata.sh <folder> [--verbose]
# Output: JSON to stdout with file metadata details
# Exit codes: 0=success, 1=bad args, 2=folder not found

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: inspect-metadata.sh <folder> [--verbose]

Show metadata for all MP3 files in a folder.

Options:
  --verbose    Include raw ffprobe output
  --help       Show this help

Output: JSON to stdout
  {"files": [{"file": "...", "title": "...", "artist": "...", "album": "...",
              "album_artist": "...", "genre": "...", "track": "...", "date": "...",
              "duration": "...", "compilation": "..."}]}
HELP
}

FOLDER=""

for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
    --verbose) ;; # Reserved for future use
    *) FOLDER="$arg" ;;
  esac
done

if [[ -z "$FOLDER" ]]; then
  echo "Error: folder argument required" >&2
  show_help >&2
  exit 1
fi

if [[ ! -d "$FOLDER" ]]; then
  echo "Error: folder not found: $FOLDER" >&2
  exit 2
fi

# Collect MP3 files
files=()
while IFS= read -r f; do files+=("$f"); done < <(find "$FOLDER" -maxdepth 1 -iname '*.mp3' -type f | sort)

if [[ ${#files[@]} -eq 0 ]]; then
  echo '{"files": []}'
  exit 0
fi

echo -n '{"files": ['
first=true
for f in "${files[@]}"; do
  # Extract metadata via ffprobe JSON
  meta=$(ffprobe -v quiet -print_format json -show_format "$f" 2>/dev/null || echo '{}')

  title=$(echo "$meta" | jq -r '.format.tags.title // .format.tags.TITLE // ""')
  artist=$(echo "$meta" | jq -r '.format.tags.artist // .format.tags.ARTIST // ""')
  album=$(echo "$meta" | jq -r '.format.tags.album // .format.tags.ALBUM // ""')
  album_artist=$(echo "$meta" | jq -r '.format.tags.album_artist // .format.tags.ALBUM_ARTIST // .format.tags.TPE2 // ""')
  genre=$(echo "$meta" | jq -r '.format.tags.genre // .format.tags.GENRE // ""')
  track=$(echo "$meta" | jq -r '.format.tags.track // .format.tags.TRACK // ""')
  date=$(echo "$meta" | jq -r '.format.tags.date // .format.tags.DATE // ""')
  duration=$(echo "$meta" | jq -r '.format.duration // ""')
  compilation=$(echo "$meta" | jq -r '.format.tags.compilation // .format.tags.COMPILATION // ""')

  filename=$(basename "$f")

  if [[ "$first" == true ]]; then
    first=false
  else
    echo -n ','
  fi

  jq -n --arg file "$filename" \
    --arg title "$title" \
    --arg artist "$artist" \
    --arg album "$album" \
    --arg album_artist "$album_artist" \
    --arg genre "$genre" \
    --arg track "$track" \
    --arg date "$date" \
    --arg duration "$duration" \
    --arg compilation "$compilation" \
    '{file: $file, title: $title, artist: $artist, album: $album,
      album_artist: $album_artist, genre: $genre, track: $track,
      date: $date, duration: $duration, compilation: $compilation}'
done
echo ']}'
