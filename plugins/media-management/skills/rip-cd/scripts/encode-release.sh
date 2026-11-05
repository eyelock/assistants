#!/usr/bin/env bash
# Make tagged MP3 320s and cleanly named WAVs from one ripped disc.
# Usage: encode-release.sh <rip_dir> <release.json> <disc> <out_dir> [--wav-only] [--cover FILE]
# Output: JSON to stdout
# Exit codes: 0=success, 1=bad args, 2=file not found, 3=ffmpeg error

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: encode-release.sh <rip_dir> <release.json> <disc> <out_dir> [--wav-only] [--cover FILE]

Turn the verified rip of one disc (01.wav, 02.wav, ... from rip-disc.sh) into
two folders under out_dir:

  out_dir/mp3/  MP3 CBR 320 kbps, fully tagged, front cover embedded
  out_dir/wav/  the ripped audio unchanged (PCM copied, never re-encoded),
                renamed, with RIFF INFO tags, plus release.json and, with
                --cover, cover.jpg

Files are named the way Apple Music names them: "1-01 Title" when the
release has more than one audio disc, "01 Title" when it has one.
Characters Apple Music and NAS shares cannot use in file names
(/ : " * ? < > |) become "_", as Apple Music writes them.

The release record is the confirmed metadata for the whole release:
  {
    "mb_release_id": "0a006c35-...",       (null when MusicBrainz had no match)
    "album": "Memento Mori: Mexico City", "album_artist": "Depeche Mode",
    "artist": "Depeche Mode", "year": "2025", "genre": "Electronic",
    "compilation": false, "disc_total": 2,
    "discs": [{"disc": 1, "mb_discid": "goxMYo...",
               "tracks": [{"n": 1, "title": "Intro", "artist": "Depeche Mode"}, ...]}]
  }
"disc_total" and "disc" count audio discs only. It is copied into the WAV
folder as release.json, so a later disc of the same release, ripped another
day, reuses exactly the same answers.

Arguments:
  rip_dir       Folder of ripped WAVs (01.wav, 02.wav, ...)
  release.json  The confirmed release record
  disc          Which audio disc of the release this rip is (1, 2, ...)
  out_dir       Folder to create mp3/ and wav/ in
  --wav-only    Only write the WAVs (repairing a release whose MP3s are
                already in Apple Music)
  --cover FILE  Front cover image to embed in the MP3s
  --help        Show this help

Output: JSON to stdout
  {"disc": 1, "mp3_dir": "...", "wav_dir": "...",
   "files": [{"n": 1, "mp3": "1-01 Intro.mp3", "wav": "1-01 Intro.wav"}, ...]}

Exit codes:
  0  Success
  1  Bad arguments, or the record has no such disc / track count differs
  2  rip_dir, release.json, a ripped track or the cover not found
  3  ffmpeg failed
HELP
}

ARGS=()
WAV_ONLY=false
COVER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) show_help; exit 0 ;;
    --wav-only) WAV_ONLY=true; shift ;;
    --cover) COVER="${2:-}"; shift 2 ;;
    -*) echo "Error: unknown option: $1" >&2; exit 1 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

RIP_DIR="${ARGS[0]:-}"
RELEASE="${ARGS[1]:-}"
DISC="${ARGS[2]:-}"
OUT="${ARGS[3]:-}"

if [[ -z "$RIP_DIR" || -z "$RELEASE" || -z "$DISC" || -z "$OUT" ]]; then
  echo "Error: rip_dir, release.json, disc and out_dir arguments required" >&2
  show_help >&2
  exit 1
fi
for path in "$RIP_DIR" "$RELEASE" ${COVER:+"$COVER"}; do
  if [[ ! -e "$path" ]]; then
    echo "Error: not found: $path" >&2
    exit 2
  fi
done

disc_json=$(jq --argjson d "$DISC" '.discs[] | select(.disc == $d)' "$RELEASE")
if [[ -z "$disc_json" ]]; then
  echo "Error: release.json has no disc $DISC" >&2
  exit 1
fi

album=$(jq -r '.album' "$RELEASE")
album_artist=$(jq -r '.album_artist // .artist' "$RELEASE")
artist=$(jq -r '.artist' "$RELEASE")
year=$(jq -r '.year // ""' "$RELEASE")
genre=$(jq -r '.genre // ""' "$RELEASE")
compilation=$(jq -r 'if .compilation then "1" else "" end' "$RELEASE")
disc_total=$(jq -r '.disc_total // 1' "$RELEASE")
mb_release=$(jq -r '.mb_release_id // ""' "$RELEASE")
mb_discid=$(echo "$disc_json" | jq -r '.mb_discid // ""')
track_total=$(echo "$disc_json" | jq '.tracks | length')

ripped=$(find "$RIP_DIR" -maxdepth 1 -name '[0-9][0-9].wav' -type f | wc -l | tr -d ' ')
if [[ "$ripped" -ne "$track_total" ]]; then
  echo "Error: rip has $ripped tracks, release.json disc $DISC has $track_total" >&2
  exit 1
fi

MP3_DIR="$OUT/mp3"
WAV_DIR="$OUT/wav"
mkdir -p "$WAV_DIR"
[[ "$WAV_ONLY" == true ]] || mkdir -p "$MP3_DIR"

files="[]"
for i in $(seq 0 $((track_total - 1))); do
  n=$(echo "$disc_json" | jq -r ".tracks[$i].n")
  title=$(echo "$disc_json" | jq -r ".tracks[$i].title")
  track_artist=$(echo "$disc_json" | jq -r ".tracks[$i].artist // empty")
  track_artist="${track_artist:-$artist}"
  src="$RIP_DIR/$(printf '%02d' "$n").wav"
  if [[ ! -f "$src" ]]; then
    echo "Error: ripped track not found: $src" >&2
    exit 2
  fi

  # Apple Music writes these as "_" in file names; NAS shares (SMB) reject
  # most of them. Matching Apple keeps the NAS mp3/ and wav/ names in step.
  safe_title=$(printf '%s' "$title" | tr '/:"*?<>|' '________')
  if [[ "$disc_total" -gt 1 ]]; then
    base=$(printf '%d-%02d %s' "$DISC" "$n" "$safe_title")
  else
    base=$(printf '%02d %s' "$n" "$safe_title")
  fi

  tags=(
    -metadata "title=$title"
    -metadata "artist=$track_artist"
    -metadata "album=$album"
    -metadata "album_artist=$album_artist"
    -metadata "track=$n/$track_total"
    -metadata "disc=$DISC/$disc_total"
  )
  [[ -n "$year" ]] && tags+=(-metadata "date=$year")
  [[ -n "$genre" ]] && tags+=(-metadata "genre=$genre")

  # WAV: copy the PCM untouched; ffmpeg writes title/artist/album/date/genre/track
  # as a RIFF INFO chunk.
  if ! ffmpeg -v error -y -i "$src" -map 0:a -c:a copy -map_metadata -1 "${tags[@]}" \
    "$WAV_DIR/$base.wav" </dev/null; then
    echo "Error: could not write $base.wav" >&2
    exit 3
  fi

  mp3=null
  if [[ "$WAV_ONLY" != true ]]; then
    extra=()
    [[ -n "$compilation" ]] && extra+=(-metadata "compilation=1")
    [[ -n "$mb_release" ]] && extra+=(-metadata "MusicBrainz Album Id=$mb_release")
    [[ -n "$mb_discid" ]] && extra+=(-metadata "MusicBrainz Disc Id=$mb_discid")
    inputs=(-i "$src")
    maps=(-map 0:a)
    if [[ -n "$COVER" ]]; then
      inputs+=(-i "$COVER")
      maps+=(-map 1:v -c:v copy -disposition:v attached_pic
        -metadata:s:v "title=Album cover" -metadata:s:v "comment=Cover (front)")
    fi
    if ! ffmpeg -v error -y "${inputs[@]}" "${maps[@]}" -c:a libmp3lame -b:a 320k \
      -map_metadata -1 -id3v2_version 3 "${tags[@]}" "${extra[@]}" \
      "$MP3_DIR/$base.mp3" </dev/null; then
      echo "Error: could not encode $base.mp3" >&2
      exit 3
    fi
    mp3="\"$base.mp3\""
  fi
  echo "Encoded: $base" >&2
  files=$(echo "$files" | jq --argjson n "$n" --argjson mp3 "$mp3" --arg wav "$base.wav" \
    '. + [{n: $n, mp3: $mp3, wav: $wav}]')
done

cp "$RELEASE" "$WAV_DIR/release.json"
# The cover goes to the NAS with the WAVs, so a later disc reuses it.
[[ -n "$COVER" ]] && cp "$COVER" "$WAV_DIR/cover.jpg"

jq -n --argjson disc "$DISC" --arg mp3_dir "$([[ "$WAV_ONLY" == true ]] || echo "$MP3_DIR")" \
  --arg wav_dir "$WAV_DIR" --argjson files "$files" \
  '{disc: $disc, mp3_dir: (if $mp3_dir == "" then null else $mp3_dir end), wav_dir: $wav_dir, files: $files}'
