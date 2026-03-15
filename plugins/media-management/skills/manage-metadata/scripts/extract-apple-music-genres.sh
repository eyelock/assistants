#!/usr/bin/env bash
# Extract unique genres from Apple Music library.
# Usage: extract-apple-music-genres.sh [--help]
# Output: JSON to stdout
# Exit codes: 0=success

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: extract-apple-music-genres.sh

Extract unique genre names from the Apple Music library.
Tries three approaches in order:
  1. AppleScript 'name of every genre' (fastest)
  2. mdfind Spotlight query (fast, indexed)
  3. AppleScript track iteration (slowest, always works)

Output: JSON to stdout
  {"genres": ["Electronic", "Ambient", ...], "source": "applescript-genres|mdfind|applescript-tracks"}
HELP
}

for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
  esac
done

output_genres() {
  local source="$1"
  shift
  # Read genres from stdin (one per line), output JSON
  jq -R -s --arg source "$source" '
    split("\n") | map(select(length > 0)) | sort | unique |
    {genres: ., source: $source}
  '
}

# Approach 1: AppleScript 'name of every genre' (fastest)
genres_raw=$(osascript -e 'tell application "Music" to get name of every genre' 2>/dev/null || echo "")
if [[ -n "$genres_raw" && "$genres_raw" != *"error"* ]]; then
  # Returns comma-separated: "Alternative, Ambient, Electronic"
  echo "$genres_raw" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$' | output_genres "applescript-genres"
  exit 0
fi

# Approach 2: mdfind Spotlight query
MUSIC_DIR="${MEDIA_MGMT_LIBRARY_STORAGE:-$HOME/Music}"
mdfind_output=$(mdfind -onlyin "$MUSIC_DIR" "kMDItemMusicalGenre == '*'" -attr kMDItemMusicalGenre 2>/dev/null || echo "")
if [[ -n "$mdfind_output" ]]; then
  echo "$mdfind_output" | grep "kMDItemMusicalGenre" | sed 's/.*= //' | sort -u | output_genres "mdfind"
  exit 0
fi

# Approach 3: AppleScript track iteration (slowest, 60s timeout)
# Use background process + wait for timeout (stock macOS has no timeout command)
osascript -e '
tell application "Music"
  set genreList to {}
  repeat with t in (every track of library playlist 1)
    set g to genre of t
    if g is not "" and g is not in genreList then
      set end of genreList to g
    end if
  end repeat
  return genreList
end tell
' > /tmp/genre-extract-$$ 2>/dev/null &
bg_pid=$!
# Wait up to 60 seconds
for _i in $(seq 1 60); do
  if ! kill -0 "$bg_pid" 2>/dev/null; then break; fi
  sleep 1
done
# Kill if still running
if kill -0 "$bg_pid" 2>/dev/null; then
  kill "$bg_pid" 2>/dev/null
  wait "$bg_pid" 2>/dev/null || true
fi
track_genres=$(cat /tmp/genre-extract-$$ 2>/dev/null || echo "")
rm -f /tmp/genre-extract-$$

if [[ -n "$track_genres" ]]; then
  echo "$track_genres" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$' | output_genres "applescript-tracks"
  exit 0
fi

# All approaches failed — return empty
echo '{"genres": [], "source": "none"}'
