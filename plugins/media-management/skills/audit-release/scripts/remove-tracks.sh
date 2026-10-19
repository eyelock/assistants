#!/usr/bin/env bash
# Remove a bad import from Apple Music once its replacement is in, moving the
# files to the Trash.
# Usage: remove-tracks.sh <snapshot.json> [--disc N ...] [--confirm TOKEN]
# Output: JSON to stdout
# Exit codes: 0=success, 1=bad args, 2=file not found, 3=Apple Music error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
  cat <<'HELP'
Usage: remove-tracks.sh <snapshot.json> [--disc N ...] [--confirm TOKEN]

Delete from the Apple Music library exactly the tracks in a snapshot, and
move their files to the Trash (recoverable; nothing is deleted outright).

The snapshot is music-tracks.sh output saved with --out BEFORE the release
was re-imported. The new import has the same album name, so only the
persistent IDs in the snapshot say which tracks are the old ones; anything
imported after the snapshot is never touched.

With --disc, only the snapshot's tracks on those discs are removed: when a
replacement is done one disc at a time, remove each disc's old tracks only
once its new ones are in, so no disc is ever left with no copy.

Without --confirm it only reports what it would remove, with a
"confirm_token" for exactly that list. Show the list to the user. Only when
they say yes to it, run again with --confirm and that token: a token from a
different list (other tracks, other discs) is refused, so nothing is removed
that was not shown first.

Arguments:
  snapshot.json  music-tracks.sh output taken before the re-import
  --disc N       Only the snapshot's tracks on disc N; repeatable
  --confirm TOKEN  Actually remove them; TOKEN is the dry run's confirm_token
  --out FILE     Also write the JSON output to FILE
  --help         Show this help

Output: JSON to stdout
  {"confirmed": false, "confirm_token": "3f9a1c2e", "tracks": [{"id": "...",
    "album": "M", "disc": 1, "track": 1, "name": "...",
    "location": "/Users/.../file.mp3", "in_library": true}],
   "removed": 0, "trashed": 0, "errors": []}

Exit codes:
  0  Success (or the dry run)
  1  Bad arguments, or a confirm token that does not match the list
  2  Snapshot not found
  3  Apple Music could not be updated
HELP
}

# shellcheck source-path=SCRIPTDIR source=../../rip-cd/scripts/lib/out.sh
source "$SCRIPT_DIR/../../rip-cd/scripts/lib/out.sh"
with_out "${BASH_SOURCE[0]}" "$@"

SNAPSHOT=""
CONFIRM=false
TOKEN=""
DISCS="[]"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) show_help; exit 0 ;;
    --confirm)
      CONFIRM=true
      TOKEN="${2:-}"
      if [[ -z "$TOKEN" || "$TOKEN" == -* ]]; then
        echo "Error: --confirm needs the confirm_token from a dry run shown to the user" >&2
        exit 1
      fi
      shift 2
      ;;
    --disc)
      if ! [[ "${2:-}" =~ ^[0-9]+$ ]]; then
        echo "Error: --disc needs a disc number" >&2
        exit 1
      fi
      DISCS=$(echo "$DISCS" | jq --argjson d "$2" '. + [$d]')
      shift 2
      ;;
    -*) echo "Error: unknown option: $1" >&2; exit 1 ;;
    *) SNAPSHOT="$1"; shift ;;
  esac
done
if [[ -z "$SNAPSHOT" ]]; then
  echo "Error: snapshot.json argument required" >&2
  show_help >&2
  exit 1
fi
if [[ ! -f "$SNAPSHOT" ]]; then
  echo "Error: file not found: $SNAPSHOT" >&2
  exit 2
fi

ids=$(jq -r --argjson discs "$DISCS" \
  '.tracks[] | select(($discs | length) == 0 or (.disc as $d | $discs | index($d))) | .id' "$SNAPSHOT")
if [[ -z "$ids" ]]; then
  echo '{"confirmed": false, "confirm_token": null, "tracks": [], "removed": 0, "trashed": 0, "errors": []}'
  exit 0
fi

# The token names exactly these tracks: a dry run prints it, --confirm needs it.
token=$(printf '%s\n' "$ids" | sort | shasum | cut -c1-8)
if [[ "$CONFIRM" == true && "$TOKEN" != "$token" ]]; then
  echo "Error: confirm token $TOKEN does not match these tracks; run without --confirm, show the list, and use its confirm_token" >&2
  exit 1
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/remove-tracks.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
echo "$ids" >"$WORK/ids.txt"

# For each ID: "id<TAB>yes|no<TAB>POSIX path" (is it still in the library,
# where is its file now). With "delete" it also removes the track.
music() {
  osascript - "$WORK/ids.txt" "$1" <<'APPLESCRIPT'
on run argv
  set wanted to paragraphs of (read (POSIX file (item 1 of argv)) as «class utf8»)
  set doDelete to (item 2 of argv) is "delete"
  set out to {}
  repeat with pid in wanted
    if length of pid > 0 then
      set loc to ""
      set found to "no"
      tell application "Music"
        try
          set t to (first track of library playlist 1 whose persistent ID is (pid as text))
          set found to "yes"
          try
            set loc to POSIX path of ((location of t) as alias)
          end try
          if doDelete then delete t
        end try
      end tell
      set end of out to (pid as text) & tab & found & tab & loc
    end if
  end repeat
  set AppleScript's text item delimiters to linefeed
  return out as text
end run
APPLESCRIPT
}

if ! state=$(music "$([[ "$CONFIRM" == true ]] && echo delete || echo look)"); then
  echo "Error: could not reach Apple Music (is it running, and is automation allowed?)" >&2
  exit 3
fi

removed=0
trashed=0
errors="[]"
tracks="[]"
while IFS=$'\t' read -r id found loc; do
  [[ -z "$id" ]] && continue
  tracks=$(echo "$tracks" | jq --arg id "$id" --arg found "$found" --arg loc "$loc" \
    --slurpfile snap "$SNAPSHOT" '. + [($snap[0].tracks[] | select(.id == $id) |
      {id, album, name, disc, track}) + {location: (if $loc == "" then null else $loc end),
      in_library: ($found == "yes")}]')
  if [[ "$CONFIRM" == true && "$found" == yes ]]; then
    removed=$((removed + 1))
    if [[ -n "$loc" && -f "$loc" ]]; then
      # Same name already in the Trash: keep both.
      dest="$HOME/.Trash/$(basename "$loc")"
      [[ -e "$dest" ]] && dest="$HOME/.Trash/$(date +%s)-$(basename "$loc")"
      if mv "$loc" "$dest"; then
        trashed=$((trashed + 1))
      else
        errors=$(echo "$errors" | jq --arg l "$loc" '. + [("could not move to the Trash: " + $l)]')
      fi
    fi
  fi
done <<<"$state"

jq -n --argjson confirmed "$CONFIRM" --arg token "$token" --argjson tracks "$tracks" \
  --argjson removed "$removed" --argjson trashed "$trashed" --argjson errors "$errors" \
  '{confirmed: $confirmed, confirm_token: $token, tracks: $tracks, removed: $removed,
    trashed: $trashed, errors: $errors}'
