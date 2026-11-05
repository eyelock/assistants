#!/usr/bin/env bash
# List an artist's tracks in the Apple Music library, with the tags that decide
# how Apple Music groups them into albums.
# Usage: music-tracks.sh --artist NAME [--album NAME ...]
# Output: JSON to stdout
# Exit codes: 0=success, 1=bad args, 3=Apple Music could not be queried

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
  cat <<'HELP'
Usage: music-tracks.sh --artist NAME [--album NAME ...]

Ask Apple Music for every track whose Artist or Album Artist contains NAME,
optionally narrowed to albums with these exact names. Read-only.

Apple Music shows one album per distinct Album + Album Artist pair (Album
Artist falling back to Artist when empty), so "groups" lists the tracks that
way: two groups for what should be one release is a split.

Arguments:
  --artist NAME   Artist to look for (substring match, case-insensitive)
  --album NAME    Keep only this album; repeat for several
  --out FILE      Also write the JSON output to FILE
  --help          Show this help

Output: JSON to stdout
  {
    "artist": "Depeche Mode",
    "tracks": [{"id": "6BD79558342ACA46", "name": "Intro (live at ...)",
                "artist": "Depeche Mode", "album_artist": "", "album": "M",
                "disc": 1, "disc_count": 2, "track": 1, "track_count": 14,
                "compilation": false, "kind": "MPEG audio file", "bit_rate": 320,
                "year": 2025, "genre": "", "seconds": 138.3,
                "location": "/Users/.../1-01 Intro (live ...).mp3"}, ...],
    "groups": [{"album": "M", "album_artist": "", "shown_as": "M — Depeche Mode",
                "tracks": 14}, ...]
  }
  "location" is null when Apple Music has no file for the track (missing,
  or only in the cloud).

Exit codes:
  0  Success (no tracks is not an error)
  1  Bad arguments
  3  Apple Music could not be queried (not running, or automation not allowed)
HELP
}

# shellcheck source-path=SCRIPTDIR source=../../rip-cd/scripts/lib/out.sh
source "$SCRIPT_DIR/../../rip-cd/scripts/lib/out.sh"
with_out "${BASH_SOURCE[0]}" "$@"

ARTIST=""
ALBUMS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) show_help; exit 0 ;;
    --artist) ARTIST="${2:-}"; shift 2 ;;
    --album) ALBUMS+=("${2:-}"); shift 2 ;;
    *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$ARTIST" ]]; then
  echo "Error: --artist required" >&2
  show_help >&2
  exit 1
fi

# One line per track, tab-separated, in the field order the jq below reads.
# One line per track, tab-separated, in the field order the jq below reads.
# Each property is fetched for every matching track in one Apple Event
# (asking track by track takes minutes for a large artist); albums, when
# given, are fetched one by one so Apple Music does the filtering.
if ! raw=$(osascript - "$ARTIST" "${ALBUMS[@]:-}" <<'APPLESCRIPT'
on run argv
  set wanted to item 1 of argv
  set albumNames to rest of argv
  set out to {}
  if albumNames is {} or albumNames is {""} then
    set out to my fetch(wanted, missing value)
  else
    repeat with a in albumNames
      set out to out & my fetch(wanted, contents of a)
    end repeat
  end if
  set AppleScript's text item delimiters to linefeed
  return out as text
end run

on fetch(wanted, albumName)
  tell application "Music"
    if albumName is missing value then
      set ts to a reference to (every track of library playlist 1 whose artist contains wanted or album artist contains wanted)
    else
      set ts to a reference to (every track of library playlist 1 whose album is albumName and (artist contains wanted or album artist contains wanted))
    end if
    if (count of ts) is 0 then return {}
    set cols to {persistent ID of ts, name of ts, artist of ts, album artist of ts, album of ts, ¬
      disc number of ts, disc count of ts, track number of ts, track count of ts, ¬
      compilation of ts, kind of ts, bit rate of ts, year of ts, genre of ts, duration of ts}
    try
      set locs to location of ts
    on error
      -- Tracks without a local file (streamed, cloud-only) have no location,
      -- and one of them fails the whole request: ask track by track.
      set locs to {}
      repeat with t in ts
        try
          set end of locs to location of t
        on error
          set end of locs to missing value
        end try
      end repeat
    end try
  end tell
  -- Lists held in a script object: AppleScript reads items of a plain
  -- local list far more slowly, which takes minutes on a large artist.
  script o
    property cols : missing value
    property locs : missing value
    property rows : {}
  end script
  set o's cols to cols
  set o's locs to locs
  set n to count of item 1 of o's cols
  set k to count of o's cols
  set AppleScript's text item delimiters to tab
  repeat with i from 1 to n
    set rec to {}
    repeat with j from 1 to k
      set end of rec to item i of item j of o's cols
    end repeat
    set loc to ""
    try
      set loc to POSIX path of ((item i of o's locs) as alias)
    end try
    set end of rec to loc
    set end of o's rows to (rec as text)
  end repeat
  return o's rows
end fetch
APPLESCRIPT
); then
  echo "Error: could not query Apple Music (is it running, and is automation allowed?)" >&2
  exit 3
fi

albums_json=$(printf '%s\n' "${ALBUMS[@]:-}" | jq -R . | jq -s 'map(select(. != ""))')

printf '%s\n' "$raw" | jq -R -s --arg artist "$ARTIST" --argjson albums "$albums_json" '
  def num: (tonumber? // 0);
  [split("\n")[] | select(length > 0) | split("\t") | {
    id: .[0], name: .[1], artist: .[2], album_artist: .[3], album: .[4],
    disc: (.[5] | num), disc_count: (.[6] | num), track: (.[7] | num), track_count: (.[8] | num),
    compilation: (.[9] == "true"), kind: .[10], bit_rate: (.[11] | num), year: (.[12] | num),
    genre: .[13], seconds: ((.[14] | gsub(",";".") | tonumber? // 0) * 10 | round / 10),
    location: (if (.[15] // "") == "" then null else .[15] end)
  }]
  | map(select(($albums | length) == 0 or (.album as $a | $albums | index($a))))
  | sort_by(.album, .disc, .track) as $tracks
  | {
      artist: $artist,
      tracks: $tracks,
      groups: ($tracks | group_by([.album, .album_artist]) | map({
        album: .[0].album, album_artist: .[0].album_artist,
        shown_as: (.[0].album + " — " + (if .[0].album_artist == "" then .[0].artist else .[0].album_artist end)),
        tracks: length
      }))
    }'
