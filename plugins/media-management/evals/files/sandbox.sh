#!/usr/bin/env bash
# Shared builders for the media-management eval sandboxes. A case's setup
# script sources this file from $EVAL_FIXTURES and calls the builders below;
# everything is made in the run's directory ($PWD), so nothing touches the real
# Downloads, Apple Music library or NAS.
#
# The world it builds, all inside the run's directory:
#   Downloads/                                   where purchases land
#   Music/Media.localized/Automatically Add to Music.localized/
#                                                Apple Music's auto-import folder
#   Music/Media.localized/Music/                 the Apple Music library on disk
#   NAS/                                         the NAS staging folder
#   config/media-management.json                 the plugin's config.json
#   .claude/settings.json                        points MEDIA_MGMT_CONFIG_PATH at
#                                                that config for the session, and
#                                                blanks every other MEDIA_MGMT_*
#                                                variable so no real value leaks in
# Audio is real: short sine tones encoded by ffmpeg, tagged like a store's
# downloads. Apple Music itself is a stub osascript (install_music_stub).
#
# Exit codes: 0 success, 3 tool error (ffmpeg, zip).
set -euo pipefail

SANDBOX="$PWD"
DOWNLOADS="$SANDBOX/Downloads"
LIBRARY_IMPORT="$SANDBOX/Music/Media.localized/Automatically Add to Music.localized"
LIBRARY_STORAGE="$SANDBOX/Music/Media.localized/Music"
ARCHIVE_WORKDIR="$SANDBOX/NAS"
CONFIG_FILE="$SANDBOX/config/media-management.json"
MUSIC_STATE="$SANDBOX/.eval/music"

# world: the folders, config.json with every required path, the session
# settings, and the Apple Music stub (so no case ever reaches the real Music
# app). Call write_settings afterwards to set env vars for the session.
world() {
  mkdir -p "$DOWNLOADS" "$LIBRARY_IMPORT" "$LIBRARY_STORAGE" "$ARCHIVE_WORKDIR" .eval
  write_config downloads library_import library_storage archive_workdir
  write_settings ""
  install_music_stub ""
}

# write_config <key>...: config.json holding only the named keys.
write_config() {
  mkdir -p "$(dirname "$CONFIG_FILE")"
  local args=() key
  for key in "$@"; do
    case "$key" in
      downloads) args+=(--arg downloads "$DOWNLOADS") ;;
      library_import) args+=(--arg library_import "$LIBRARY_IMPORT") ;;
      library_storage) args+=(--arg library_storage "$LIBRARY_STORAGE") ;;
      archive_workdir) args+=(--arg archive_workdir "$ARCHIVE_WORKDIR") ;;
    esac
  done
  jq -n "${args[@]}" '$ARGS.named' >"$CONFIG_FILE"
}

# write_settings [KEY=VALUE]...: the session's env, via project settings. Each
# KEY=VALUE becomes a session env var (for example MEDIA_MGMT_DOWNLOADS=/path),
# the way a user's shell profile would set it.
write_settings() {
  mkdir -p .claude
  local env
  env=$(jq -n --arg config "$CONFIG_FILE" '{
    MEDIA_MGMT_CONFIG_PATH: $config, MEDIA_MGMT_DOWNLOADS: "",
    MEDIA_MGMT_LIBRARY_IMPORT: "", MEDIA_MGMT_LIBRARY_STORAGE: "",
    MEDIA_MGMT_ARCHIVE_WORKDIR: "", MEDIA_MGMT_PROCESSED: "",
    MEDIA_MGMT_REKORDBOX_MCP_PATH: ""}')
  local pair
  for pair in "$@"; do
    [[ -n "$pair" ]] || continue
    env=$(jq --arg k "${pair%%=*}" --arg v "${pair#*=}" '.[$k] = $v' <<<"$env")
  done
  jq -n --argjson env "$env" '{env: $env}' >.claude/settings.json
}

# tone <hz> <seconds>: a sine with a little pink noise under it, so WAVs do not
# compress to nothing and a WAV ZIP is larger than its MP3 ZIP, as in life.
tone() {
  echo "sine=f=$1:r=22050:d=$2[s];anoisesrc=r=22050:d=$2:c=pink:a=0.05[n];[s][n]amix=inputs=2"
}

# mp3 <file> <seconds> <hz> [tag=value]...: a tagged MP3 tone.
mp3() {
  local file="$1" secs="$2" hz="$3"
  shift 3
  local meta=() tag
  for tag in "$@"; do meta+=(-metadata "$tag"); done
  mkdir -p "$(dirname "$file")"
  ffmpeg -v error -filter_complex "$(tone "$hz" "$secs")" -ac 1 -c:a libmp3lame -b:a 64k \
    -id3v2_version 3 "${meta[@]+"${meta[@]}"}" -y "$file" || exit 3
}

# wav <file> <seconds> <hz> [tag=value]...: a WAV tone (16-bit, as stores ship).
wav() {
  local file="$1" secs="$2" hz="$3"
  shift 3
  local meta=() tag
  for tag in "$@"; do meta+=(-metadata "$tag"); done
  mkdir -p "$(dirname "$file")"
  ffmpeg -v error -filter_complex "$(tone "$hz" "$secs")" -ac 1 -c:a pcm_s16le \
    "${meta[@]+"${meta[@]}"}" -y "$file" || exit 3
}

# cover <file>: the small cover.jpg stores put in every ZIP.
cover() {
  mkdir -p "$(dirname "$1")"
  ffmpeg -v error -f lavfi -i "color=c=navy:s=64x64" -frames:v 1 -y "$1" || exit 3
}

# zipup <zip> <dir>: a ZIP of every file in <dir>, flat, as stores ship them.
zipup() {
  mkdir -p "$(dirname "$1")"
  (cd "$2" && zip -q -X "$1" ./*) || exit 3
}

# --- Releases -----------------------------------------------------------------

AFTERGLOW_TITLES=("Dusk" "Neon Rain" "Overpass" "Last Train")

# afterglow_mp3s <dir> [tag=value]...: Night Drive - Afterglow as Bandcamp
# names its MP3s, 4 tracks, genre Electronic, no Album Artist. Extra tags
# apply to every track.
afterglow_mp3s() {
  local dir="$1" i n
  shift
  for i in 0 1 2 3; do
    n=$((i + 1))
    mp3 "$dir/Night Drive - Afterglow - 0$n ${AFTERGLOW_TITLES[$i]}.mp3" $((4 + i)) $((300 + 60 * i)) \
      "title=${AFTERGLOW_TITLES[$i]}" "artist=Night Drive" "album=Afterglow" "track=$n" \
      "genre=Electronic" "date=2026" "$@"
  done
}

# afterglow_wavs <dir>: the same release's WAVs, vendor-named.
afterglow_wavs() {
  local dir="$1" i n
  for i in 0 1 2 3; do
    n=$((i + 1))
    wav "$dir/Night Drive - Afterglow - 0$n ${AFTERGLOW_TITLES[$i]}.wav" $((4 + i)) $((300 + 60 * i)) \
      "title=${AFTERGLOW_TITLES[$i]}" "artist=Night Drive" "album=Afterglow" "track=$n"
  done
}

# afterglow_zips: the release's ZIP pair in Downloads, as bought: the MP3 ZIP
# and the WAV ZIP ("-2"), each with a cover.jpg.
afterglow_zips() {
  local tmp="$SANDBOX/.eval/gen"
  rm -rf "$tmp" && mkdir -p "$tmp/mp3" "$tmp/wav"
  afterglow_mp3s "$tmp/mp3"
  afterglow_wavs "$tmp/wav"
  cover "$tmp/mp3/cover.jpg"
  cp "$tmp/mp3/cover.jpg" "$tmp/wav/cover.jpg"
  zipup "$DOWNLOADS/Night Drive - Afterglow.zip" "$tmp/mp3"
  zipup "$DOWNLOADS/Night Drive - Afterglow-2.zip" "$tmp/wav"
  rm -rf "$tmp"
}

# afterglow_remixes_zip: a different, unprocessed release whose name starts
# with the same words: "Night Drive - Afterglow (Remixes).zip".
afterglow_remixes_zip() {
  local tmp="$SANDBOX/.eval/gen"
  rm -rf "$tmp" && mkdir -p "$tmp"
  mp3 "$tmp/Night Drive - Afterglow (Remixes) - 01 Dusk (Aster Remix).mp3" 5 520 \
    "title=Dusk (Aster Remix)" "artist=Night Drive" "album=Afterglow (Remixes)" "track=1"
  mp3 "$tmp/Night Drive - Afterglow (Remixes) - 02 Overpass (Deep Room Remix).mp3" 5 560 \
    "title=Overpass (Deep Room Remix)" "artist=Night Drive" "album=Afterglow (Remixes)" "track=2"
  zipup "$DOWNLOADS/Night Drive - Afterglow (Remixes).zip" "$tmp"
  rm -rf "$tmp"
}

SAMPLER_ARTISTS=("Kora Lune" "Night Drive" "Deep Room" "Aster")
SAMPLER_TITLES=("Tidal" "Harbour Lights" "Undertow" "Glasshouse")

# sampler_mp3s <dir>: Summer Sampler, a label compilation of four artists,
# genre House, no Album Artist and no compilation flag (as Bandcamp ships it).
sampler_mp3s() {
  local dir="$1" i n
  for i in 0 1 2 3; do
    n=$((i + 1))
    mp3 "$dir/Tidal Records - Summer Sampler - 0$n ${SAMPLER_ARTISTS[$i]} - ${SAMPLER_TITLES[$i]}.mp3" \
      $((4 + i)) $((400 + 50 * i)) "title=${SAMPLER_TITLES[$i]}" "artist=${SAMPLER_ARTISTS[$i]}" \
      "album=Summer Sampler" "track=$n" "genre=House" "date=2026"
  done
}

# sampler_zips: the compilation's ZIP pair, named the way the store names a
# multi-artist release: after every contributing artist.
sampler_zips() {
  local tmp="$SANDBOX/.eval/gen" i n
  rm -rf "$tmp" && mkdir -p "$tmp/mp3" "$tmp/wav"
  sampler_mp3s "$tmp/mp3"
  for i in 0 1 2 3; do
    n=$((i + 1))
    wav "$tmp/wav/Tidal Records - Summer Sampler - 0$n ${SAMPLER_ARTISTS[$i]} - ${SAMPLER_TITLES[$i]}.wav" \
      $((4 + i)) $((400 + 50 * i)) "title=${SAMPLER_TITLES[$i]}" "artist=${SAMPLER_ARTISTS[$i]}"
  done
  zipup "$DOWNLOADS/Kora Lune, Night Drive, Deep Room, Aster - Summer Sampler.zip" "$tmp/mp3"
  zipup "$DOWNLOADS/Kora Lune, Night Drive, Deep Room, Aster - Summer Sampler-2.zip" "$tmp/wav"
  rm -rf "$tmp"
}

# tidal_single: a one-track purchase that downloads as loose files, no ZIP.
tidal_single() {
  mp3 "$DOWNLOADS/Kora Lune - Tidal.mp3" 6 440 "title=Tidal" "artist=Kora Lune" \
    "album=Tidal" "track=1" "genre=House"
  wav "$DOWNLOADS/Kora Lune - Tidal.wav" 6 440 "title=Tidal" "artist=Kora Lune"
}

# long_set <dir>: DJ Aster - Live at Dawn: an intro, an 80-minute live mix
# with one 2-second silence at 39:00, and an outro. Apple Music rejects tracks
# over 78 minutes.
long_set() {
  local dir="$1"
  mkdir -p "$dir"
  mp3 "$dir/01 Intro.mp3" 5 500 "title=Intro" "artist=DJ Aster" "album=Live at Dawn" \
    "track=1/3" "genre=House"
  ffmpeg -v error -f lavfi -i "sine=f=220:r=8000:d=2340" -f lavfi -i "anullsrc=r=8000:cl=mono:d=2" \
    -f lavfi -i "sine=f=330:r=8000:d=2460" -filter_complex "[0][1][2]concat=n=3:v=0:a=1" \
    -ac 1 -c:a libmp3lame -b:a 8k -id3v2_version 3 -metadata "title=Live at Dawn" \
    -metadata "artist=DJ Aster" -metadata "album=Live at Dawn" -metadata "track=2/3" \
    -metadata "genre=House" -y "$dir/02 Live at Dawn.mp3" || exit 3
  mp3 "$dir/03 Outro.mp3" 5 600 "title=Outro" "artist=DJ Aster" "album=Live at Dawn" \
    "track=3/3" "genre=House"
}

# clutter: the unrelated files every Downloads folder has.
clutter() {
  printf '%%PDF-1.4\n%% invoice 2026-10-01\n' >"$DOWNLOADS/Invoice-2026-10.pdf"
  local tmp="$SANDBOX/.eval/gen"
  rm -rf "$tmp" && mkdir -p "$tmp"
  printf 'Quarterly numbers\n' >"$tmp/report.txt"
  printf 'a,b\n1,2\n' >"$tmp/data.csv"
  zipup "$DOWNLOADS/report.zip" "$tmp"
  rm -rf "$tmp"
}

# --- Apple Music stub -----------------------------------------------------------

# install_music_stub [key=value]...: an osascript on PATH that plays Apple
# Music for the plugin's AppleScripts, from a library model in
# .eval/music/library.env. It answers the genre list, the reclaim-space audit
# and the offload-playlist build (honouring --replace, keep folder, grouping
# and kind exclusions), keeps the playlists it makes in .eval/music/playlists,
# and logs every call, labelled, to $EVAL_STUB_LOG. Any other script gets the
# error Music gives when automation is not allowed.
# Model keys (defaults): total=12000 matched=7000 uploaded=4200 purchased=50
# subscription=300 ineligible=400 unknown=50 keep_folder=Crates keep_tracks=1800
# wav_tracks=350 dj_grouping_tracks=900 genres="Ambient, Electronic, House, Techno"
install_music_stub() {
  mkdir -p "$MUSIC_STATE"
  touch "$MUSIC_STATE/playlists"
  {
    echo "total=12000"
    echo "matched=7000"
    echo "uploaded=4200"
    echo "purchased=50"
    echo "subscription=300"
    echo "ineligible=400"
    echo "unknown=50"
    echo "keep_folder=Crates"
    echo "keep_tracks=1800"
    echo "wav_tracks=350"
    echo "dj_grouping_tracks=900"
    echo "genres='Ambient, Electronic, House, Techno'"
    local kv
    for kv in "$@"; do
      [[ -n "$kv" ]] || continue
      printf '%s=%q\n' "${kv%%=*}" "${kv#*=}"
    done
  } >"$MUSIC_STATE/library.env"
  cp "$EVAL_FIXTURES/osascript-stub.sh" "$EVAL_BIN/osascript"
  chmod +x "$EVAL_BIN/osascript"
}

# playlist <name> [tracks]: a playlist that already exists in the stub's library.
playlist() {
  printf '%s\t%s\n' "$1" "${2:-8100}" >>"$MUSIC_STATE/playlists"
}

# snapshot: record every file's checksum, so the evidence can show what the
# run added, removed or changed.
snapshot() {
  rm -rf "$SANDBOX/.eval/gen"
  bash "$EVAL_FIXTURES/evidence.sh" --manifest >"$SANDBOX/.eval/before.txt"
}
