#!/usr/bin/env bash
# Retag a release's tracks in Apple Music to match its release record, so a
# split album merges back into one, in place, without re-importing.
# Usage: repair-release.sh plan --artist NAME --album NAME [--album ...] --release FILE [--cover FILE]
#        repair-release.sh apply <plan.json>
#        repair-release.sh revert <plan.json>
# Output: JSON to stdout
# Exit codes: 0=success, 1=bad args, 2=file not found, 3=Apple Music or ffmpeg error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
  cat <<'HELP'
Usage: repair-release.sh plan --artist NAME --album NAME [--album ...] --release FILE [--cover FILE]
       repair-release.sh apply <plan.json>
       repair-release.sh revert <plan.json>

plan    Read-only. Match every track Apple Music has for the release to the
        release record by disc and track number, and work out each change:
        Name, Artist, Album, Album Artist, Disc n/N, Track n/N, Year, Genre,
        Compilation. Each track's full before and after values are kept, so
        the plan is also the undo. Tracks whose length differs from the
        record's by more than 3 seconds are listed under "warnings": they
        may not be the same recording, and are left out of the plan.
        With --cover (from rip-cd's fetch-cover.sh), every track gets that
        front cover, replacing whatever Apple Music found itself.
apply   Set the "after" values through Apple Music (it rewrites the file
        tags and, when it organises the library, moves the files into the
        new album folder), then write the MusicBrainz Album Id and Disc Id
        into each file, which Apple Music has no field for.
revert  Set the "before" values back, and remove the MusicBrainz tags and
        the cover from files that had none. Apple Music's own artwork guess
        is not restored.

Save the plan with --out FILE (it also prints it), show it to the user,
and apply only when they agree.

  --out FILE  Also write the JSON output to FILE (any mode)

Output (plan): JSON to stdout
  {
    "release": "Depeche Mode: M", "mb_release_id": "...",
    "tracks": [{"id": "6BD79558342ACA46", "disc": 1, "track": 1,
                "before": {"name": "Intro (live at ...)", "album": "M", ...},
                "after": {"name": "Intro", "album": "Depeche Mode: M", ...},
                "changes": ["name", "album", "album_artist"],
                "file_tags": {"MusicBrainz Album Id": "...", "MusicBrainz Disc Id": "..."},
                "had_file_tags": false}],
    "summary": [{"field": "album", "from": ["M", "M [Disc 2]"], "to": ["Depeche Mode: M"],
                 "tracks": 28}, ...],
    "warnings": [], "unmatched_tracks": [], "missing_from_library": []
  }
Output (apply/revert): {"applied": 28, "file_tags_written": 28, "errors": []}

Exit codes:
  0  Success
  1  Bad arguments
  2  Plan or release file not found
  3  Apple Music could not be updated, or a file's tags could not be written
HELP
}

# shellcheck source-path=SCRIPTDIR source=../../rip-cd/scripts/lib/out.sh
source "$SCRIPT_DIR/../../rip-cd/scripts/lib/out.sh"
with_out "${BASH_SOURCE[0]}" "$@"

MODE="${1:-}"
if [[ -z "$MODE" ]]; then
  show_help >&2
  exit 1
fi
if [[ "$MODE" == "--help" ]]; then
  show_help
  exit 0
fi
shift

if [[ "$MODE" == "plan" ]]; then
  ARTIST=""
  ALBUM_ARGS=()
  RELEASE=""
  COVER=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help) show_help; exit 0 ;;
      --artist) ARTIST="${2:-}"; shift 2 ;;
      --album) ALBUM_ARGS+=(--album "${2:-}"); shift 2 ;;
      --release) RELEASE="${2:-}"; shift 2 ;;
      --cover) COVER="${2:-}"; shift 2 ;;
      *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
    esac
  done
  if [[ -n "$COVER" && ! -f "$COVER" ]]; then
    echo "Error: file not found: $COVER" >&2
    exit 2
  fi
  [[ -n "$COVER" ]] && COVER="$(cd "$(dirname "$COVER")" && pwd)/$(basename "$COVER")"
  if [[ -z "$ARTIST" || ${#ALBUM_ARGS[@]} -eq 0 || -z "$RELEASE" ]]; then
    echo "Error: plan needs --artist, at least one --album, and --release" >&2
    exit 1
  fi
  if [[ ! -f "$RELEASE" ]]; then
    echo "Error: file not found: $RELEASE" >&2
    exit 2
  fi
  TRACKS=$(mktemp "${TMPDIR:-/tmp}/repair-tracks.XXXXXX")
  trap 'rm -f "$TRACKS"' EXIT
  bash "$SCRIPT_DIR/music-tracks.sh" --artist "$ARTIST" "${ALBUM_ARGS[@]}" >"$TRACKS" || exit 3

  # Which files already carry a MusicBrainz Album Id or an embedded cover, so
  # revert can tell what it added from what was there.
  probes=$(jq -r '.tracks[] | select(.location) | [.id, .location] | @tsv' "$TRACKS" |
    while IFS=$'\t' read -r id loc; do
      ffprobe -v quiet -show_format -show_streams -of json "$loc" 2>/dev/null | jq -r --arg id "$id" '
        (if any(.format.tags | keys[]?; ascii_downcase == "musicbrainz album id") then "tag:" + $id else empty end),
        (if any(.streams[]?; .disposition.attached_pic == 1) then "art:" + $id else empty end)'
    done)

  python3 -I - "$TRACKS" "$RELEASE" "$probes" "$COVER" <<'PY'
import json, sys

tracks = json.load(open(sys.argv[1]))["tracks"]
rec = json.load(open(sys.argv[2]))
probes = sys.argv[3].split()
tagged = {p[4:] for p in probes if p.startswith("tag:")}
has_art = {p[4:] for p in probes if p.startswith("art:")}
cover = sys.argv[4] or None
FIELDS = ["name", "artist", "album", "album_artist", "disc", "disc_count", "track",
          "track_count", "year", "genre", "compilation"]

want = {}
for d in rec["discs"]:
    for t in d["tracks"]:
        want[(d["disc"], t["n"])] = (d, t)

plan, warnings, unmatched, seen = [], [], [], set()
for t in tracks:
    key = (t["disc"], t["track"])
    if key not in want:
        unmatched.append({"id": t["id"], "disc": t["disc"], "track": t["track"], "name": t["name"]})
        continue
    d, rt = want[key]
    if rt.get("seconds") and t["seconds"] and abs(rt["seconds"] - t["seconds"]) > 3:
        warnings.append("disc %d track %d %r is %.0fs, the record's %r is %.0fs: left unchanged"
                        % (key[0], key[1], t["name"], t["seconds"], rt["title"], rt["seconds"]))
        continue
    seen.add(key)
    before = {f: t[f] for f in FIELDS}
    after = dict(before)
    after.update({
        "name": rt["title"], "artist": rt.get("artist") or rec["artist"],
        "album": rec["album"], "album_artist": rec["album_artist"],
        "disc": d["disc"], "disc_count": rec["disc_total"],
        "track": rt["n"], "track_count": len(d["tracks"]),
        "compilation": bool(rec.get("compilation")),
    })
    if rec.get("year"):
        after["year"] = int(rec["year"])
    if rec.get("genre"):
        after["genre"] = rec["genre"]
    file_tags = {}
    if rec.get("mb_release_id"):
        file_tags["MusicBrainz Album Id"] = rec["mb_release_id"]
    if d.get("mb_discid"):
        file_tags["MusicBrainz Disc Id"] = d["mb_discid"]
    plan.append({"id": t["id"], "disc": key[0], "track": key[1], "location": t["location"],
                 "before": before, "after": after,
                 "changes": [f for f in FIELDS if before[f] != after[f]],
                 "file_tags": file_tags, "had_file_tags": t["id"] in tagged,
                 "had_artwork": t["id"] in has_art})

summary = []
for f in FIELDS:
    changed = [p for p in plan if f in p["changes"]]
    if changed:
        summary.append({"field": f, "tracks": len(changed),
                        "from": sorted({str(p["before"][f]) for p in changed})[:6],
                        "to": sorted({str(p["after"][f]) for p in changed})[:6]})

missing = ["disc %d track %d %r" % (k[0], k[1], want[k][1]["title"]) for k in sorted(want) if k not in seen]
if cover:
    summary.append({"field": "artwork", "tracks": len(plan),
                    "from": ["embedded" if p["had_artwork"] else "none (Apple Music's own guess)" for p in plan][:1],
                    "to": [cover]})
json.dump({"release": rec["album"], "mb_release_id": rec.get("mb_release_id"), "cover": cover, "tracks": plan,
           "summary": summary, "warnings": warnings, "unmatched_tracks": unmatched,
           "missing_from_library": missing}, sys.stdout, indent=2, ensure_ascii=False)
print()
PY
  exit 0
fi

if [[ "$MODE" != "apply" && "$MODE" != "revert" ]]; then
  echo "Error: mode must be plan, apply or revert, got: $MODE" >&2
  exit 1
fi

PLAN="${1:-}"
if [[ -z "$PLAN" ]]; then
  echo "Error: $MODE needs the plan file" >&2
  exit 1
fi
if [[ ! -f "$PLAN" ]]; then
  echo "Error: file not found: $PLAN" >&2
  exit 2
fi

SIDE=after
[[ "$MODE" == "revert" ]] && SIDE=before

WORK=$(mktemp -d "${TMPDIR:-/tmp}/repair-apply.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

# Values go to AppleScript through a file, one tab-separated line per track,
# so no title needs quoting or escaping.
# The last column says what to do with the artwork: set the plan's cover,
# delete it (revert, when the file had none), or keep what is there.
# Only tracks with something to do: a changed field, a cover to set, or
# MusicBrainz tags the file lacks. Revert undoes exactly the same tracks.
jq -r --arg side "$SIDE" --arg mode "$MODE" '(.cover // "") as $cover | .tracks[] |
  select((.changes | length) > 0 or $cover != "" or (.had_file_tags | not)) |
  [.id, (.[$side] | .name, .artist, .album, .album_artist,
  (.disc|tostring), (.disc_count|tostring), (.track|tostring), (.track_count|tostring),
  (.year|tostring), .genre, (.compilation|tostring)),
  (if $cover == "" then "keep" elif $mode == "apply" then "set"
   elif .had_artwork then "keep" else "delete" end)] | @tsv' "$PLAN" >"$WORK/values.tsv"
COVER=$(jq -r '.cover // ""' "$PLAN")
if [[ -n "$COVER" && ! -f "$COVER" ]]; then
  echo "Error: the plan's cover is gone: $COVER" >&2
  exit 2
fi

count=$(wc -l <"$WORK/values.tsv" | tr -d ' ')
if [[ "$count" -eq 0 ]]; then
  echo '{"applied": 0, "file_tags_written": 0, "errors": []}'
  exit 0
fi

# Prints "id<TAB>POSIX path" for each track it set, or "id<TAB>ERROR message".
if ! results=$(osascript - "$WORK/values.tsv" "$COVER" <<'APPLESCRIPT'
on run argv
  set raw to read (POSIX file (item 1 of argv)) as «class utf8»
  set coverData to missing value
  if (item 2 of argv) is not "" then set coverData to read (POSIX file (item 2 of argv)) as JPEG picture
  set out to {}
  set AppleScript's text item delimiters to tab
  repeat with ln in paragraphs of raw
    if length of ln > 0 then
      set v to text items of ln
      try
        tell application "Music"
          set t to (first track of library playlist 1 whose persistent ID is (item 1 of v))
          set name of t to item 2 of v
          set artist of t to item 3 of v
          set album of t to item 4 of v
          set album artist of t to item 5 of v
          set disc number of t to (item 6 of v) as integer
          set disc count of t to (item 7 of v) as integer
          set track number of t to (item 8 of v) as integer
          set track count of t to (item 9 of v) as integer
          set year of t to (item 10 of v) as integer
          set genre of t to item 11 of v
          set compilation of t to ((item 12 of v) is "true")
          if (item 13 of v) is "set" and coverData is not missing value then
            set data of artwork 1 of t to coverData
          else if (item 13 of v) is "delete" then
            delete artworks of t
          end if
          set loc to ""
          try
            set loc to POSIX path of ((location of t) as alias)
          end try
        end tell
        set end of out to (item 1 of v) & tab & loc
      on error msg
        set end of out to (item 1 of v) & tab & "ERROR " & msg
      end try
    end if
  end repeat
  set AppleScript's text item delimiters to linefeed
  return out as text
end run
APPLESCRIPT
); then
  echo "Error: could not update Apple Music (is it running, and is automation allowed?)" >&2
  exit 3
fi

errors="[]"
applied=0
written=0
while IFS=$'\t' read -r id loc; do
  [[ -z "$id" ]] && continue
  if [[ "$loc" == ERROR* ]]; then
    errors=$(echo "$errors" | jq --arg id "$id" --arg m "${loc#ERROR }" '. + [{id: $id, error: $m}]')
    continue
  fi
  applied=$((applied + 1))
  [[ -z "$loc" || ! -f "$loc" ]] && continue

  # The MusicBrainz tags Apple Music cannot hold: set them on apply; on revert,
  # clear them unless the file had them before.
  tag_args=()
  while IFS=$'\t' read -r k v; do
    [[ -z "$k" ]] && continue
    tag_args+=(-metadata "$k=$v")
  done < <(jq -r --arg id "$id" --arg mode "$MODE" '.tracks[] | select(.id == $id) |
    if $mode == "revert" and .had_file_tags then empty
    else .file_tags | to_entries[] | [.key, (if $mode == "revert" then "" else .value end)] | @tsv end' "$PLAN")
  [[ ${#tag_args[@]} -eq 0 ]] && continue

  tmp="${loc%.*}.retag-tmp.mp3"
  if ffmpeg -v error -y -i "$loc" -map 0 -c copy -map_metadata 0 -id3v2_version 3 \
    "${tag_args[@]}" "$tmp" </dev/null && mv "$tmp" "$loc"; then
    written=$((written + 1))
  else
    rm -f "$tmp"
    errors=$(echo "$errors" | jq --arg id "$id" --arg loc "$loc" '. + [{id: $id, error: ("could not write tags to " + $loc)}]')
  fi
done <<<"$results"

jq -n --argjson applied "$applied" --argjson written "$written" --argjson errors "$errors" \
  '{applied: $applied, file_tags_written: $written, errors: $errors}'

[[ "$(echo "$errors" | jq length)" -eq 0 ]] || exit 3
