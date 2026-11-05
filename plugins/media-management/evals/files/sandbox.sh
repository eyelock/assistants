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
    echo "library_import='$LIBRARY_IMPORT'"
    echo "library_storage='$LIBRARY_STORAGE'"
    local kv
    for kv in "$@"; do
      [[ -n "$kv" ]] || continue
      printf '%s=%q\n' "${kv%%=*}" "${kv#*=}"
    done
  } >"$MUSIC_STATE/library.env"
  cp "$EVAL_FIXTURES/osascript-stub.sh" "$EVAL_BIN/osascript"
  cp "$EVAL_FIXTURES/music-model.py" "$MUSIC_STATE/music-model.py"
  chmod +x "$EVAL_BIN/osascript"
  # Apple Music imports from the auto-import folder while something waits
  # for it: a sleep (import-mp3s.sh --wait) gives it the moment to.
  cat >"$EVAL_BIN/sleep" <<STUB
#!/usr/bin/env bash
python3 -I "$MUSIC_STATE/music-model.py" "$MUSIC_STATE" ingest 2>/dev/null
exec /bin/sleep 0.1
STUB
  chmod +x "$EVAL_BIN/sleep"
}

# --- The optical drive -----------------------------------------------------------

CD_STATE="$SANDBOX/.eval/cd"

# install_cd_stubs <disc|none>: the drive (cd-paranoia, drutil, diskutil) and
# the web (curl: MusicBrainz, AccurateRip, Cover Art Archive), all played by
# cd-stub.sh from cd-fixture.py's release, Night Drive - Afterglow Live (a
# DVD + 2 CD box, and the same CDs as a 2-CD edition). The drive's read offset
# is +6 samples, set in config as cd_read_offset.
install_cd_stubs() {
  mkdir -p "$CD_STATE" "$SANDBOX/.eval/web"
  cp "$EVAL_FIXTURES/cd-fixture.py" "$CD_STATE/cd-fixture.py"
  echo "${1:-1}" >"$CD_STATE/disc"
  local tool
  for tool in cd-paranoia drutil diskutil curl; do
    cp "$EVAL_FIXTURES/cd-stub.sh" "$EVAL_BIN/$tool"
    chmod +x "$EVAL_BIN/$tool"
  done
  python3 -I "$CD_STATE/cd-fixture.py" web "$SANDBOX/.eval/web" "$EVAL_FIXTURES/../../skills/rip-cd/scripts/lib" || exit 3
  local id
  for id in 5e1d1c3a-7a10-4b2e-9c55-0b1d2e3f4a01 5e1d1c3a-7a10-4b2e-9c55-0b1d2e3f4a02; do
    ffmpeg -v error -f lavfi -i "color=c=0x1d3557:s=600x600" -frames:v 1 -y \
      "$SANDBOX/.eval/web/cover-$id.jpg" || exit 3
  done
  echo '{"count": 0, "releases": []}' >"$SANDBOX/.eval/web/mb-search-empty.json"
  # Work folders go to the run's own temp folder (the only place a command may
  # write), as a real run's go to $TMPDIR: never Downloads.
  mkdir -p "$WORK_BASE"
  jq --argjson o 6 --arg w "$WORK_BASE" '. + {cd_read_offset: $o, work_dir: $w}' "$CONFIG_FILE" \
    >"$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
}

WORK_BASE="$SANDBOX/tmp/media-management"
SKILLS="$EVAL_FIXTURES/../../skills"
SET_WORK="$WORK_BASE/cd-rip-Night Drive - Afterglow Live"
CD2_EDITION=5e1d1c3a-7a10-4b2e-9c55-0b1d2e3f4a02

# plugin <skill>/<script> [args]...: run one of the plugin's own scripts the
# way the skill would, against the sandbox (its stubs, its config).
plugin() {
  local script="$1"
  shift
  PATH="$EVAL_BIN:$PATH" MEDIA_MGMT_CONFIG_PATH="$CONFIG_FILE" \
    bash "$SKILLS/$script" "$@" >/dev/null 2>"$SANDBOX/.eval/plugin-$(basename "$script").err" || {
    echo "setup: $script failed:" >&2
    cat "$SANDBOX/.eval/plugin-$(basename "$script").err" >&2
    exit 3
  }
}

# disc_done <n> [encoded|archive]: disc n of the 2-CD edition taken through
# rip-cd as a user would have, earlier: answers given (genre Electronic,
# MusicBrainz's titles in plain punctuation), ripped, verified, encoded, then
# (unless "encoded") imported to Apple Music and (with "archive") staged to
# the NAS. Work goes to $SET_WORK.
disc_done() {
  local n="$1" mode="${2:-}"
  insert_disc "$n"
  mkdir -p "$SET_WORK"
  plugin rip-cd/scripts/read-disc.sh --out "$SET_WORK/disc$n.json"
  local discid
  discid=$(jq -r .musicbrainz.discid "$SET_WORK/disc$n.json")
  if [[ ! -f "$SET_WORK/release.json" ]]; then
    plugin rip-cd/scripts/make-release-record.sh --release-id "$CD2_EDITION" --genre Electronic \
      --plain-punctuation --discid "$n=$discid" --out "$SET_WORK/release.json"
    plugin rip-cd/scripts/fetch-cover.sh "$CD2_EDITION" "$SET_WORK/cover.jpg"
  else
    plugin rip-cd/scripts/update-record.sh "$SET_WORK/release.json" --disc "$n" --discid "$discid"
  fi
  plugin rip-cd/scripts/rip-disc.sh "$SET_WORK/rip-disc$n" --offset 6 --out "$SET_WORK/rip-disc$n.json"
  plugin rip-cd/scripts/verify-accuraterip.sh "$SET_WORK/rip-disc$n" "$SET_WORK/disc$n.json"
  plugin rip-cd/scripts/update-record.sh "$SET_WORK/release.json" --disc "$n" --accuraterip verified
  plugin rip-cd/scripts/encode-release.sh "$SET_WORK/rip-disc$n" "$SET_WORK/release.json" "$n" \
    "$SET_WORK/disc$n" --cover "$SET_WORK/cover.jpg"
  [[ "$mode" == encoded ]] && return 0
  cp "$SET_WORK/disc$n/mp3/"*.mp3 "$LIBRARY_IMPORT/"
  python3 -I "$MUSIC_STATE/music-model.py" "$MUSIC_STATE" ingest || exit 3
  if [[ "$mode" == archive ]]; then
    plugin archive-media/scripts/archive-files.sh mp3 "$LIBRARY_STORAGE/Night Drive/Afterglow Live" \
      "$ARCHIVE_WORKDIR/to_nas/mp3/Night Drive/Afterglow Live"
    plugin archive-media/scripts/archive-files.sh wav "$SET_WORK/disc$n/wav" \
      "$ARCHIVE_WORKDIR/to_nas/wav/Night Drive/Afterglow Live"
  fi
}

# days_later: the work folder is gone (the system cleared its temp folder);
# only what the NAS and Apple Music hold remains.
days_later() {
  rm -rf "$WORK_BASE"
  mkdir -p "$WORK_BASE"
}

# insert_disc <1|2|none>: change the disc in the drive.
insert_disc() {
  echo "$1" >"$CD_STATE/disc"
}

# library_mp3 <album> <album_artist> <disc>/<discs> <track>/<tracks> <title> <seconds> [tag=value]...:
# a track already in the Apple Music library (imported before the run), as an
# MP3 320 filed where Apple Music files it.
library_mp3() {
  local album="$1" aa="$2" disc="$3" track="$4" title="$5" secs="$6"
  shift 6
  local tmp="$SANDBOX/.eval/gen/import"
  mkdir -p "$tmp"
  ffmpeg -v error -filter_complex "$(tone $((200 + ${track%%/*} * 40)) "$secs")" -ac 2 -ar 44100 \
    -c:a libmp3lame -b:a 320k -id3v2_version 3 -metadata "title=$title" -metadata "artist=Night Drive" \
    -metadata "album=$album" -metadata "album_artist=$aa" -metadata "disc=$disc" \
    -metadata "track=$track" -metadata "date=2026" "$@" -y "$tmp/$title.mp3" </dev/null || exit 3
  mv "$tmp/$title.mp3" "$LIBRARY_IMPORT/"
  python3 -I "$MUSIC_STATE/music-model.py" "$MUSIC_STATE" ingest || exit 3
}

# half_done_import: Afterglow Live as Apple Music's own CD import left it:
# each disc its own album ("Afterglow Live" and "Afterglow Live [Disc 2]"),
# no Album Artist, the live suffix on every title, no embedded artwork, and
# nothing on the NAS.
half_done_import() {
  local suffix=" (Live at Hall 7, Berlin 14.03.26)"
  library_mp3 "Afterglow Live" "" 1/2 1/3 "Dusk$suffix" 7 -metadata genre=Electronic
  library_mp3 "Afterglow Live" "" 1/2 2/3 "Neon Rain$suffix" 6 -metadata genre=Electronic
  library_mp3 "Afterglow Live" "" 1/2 3/3 "Overpass (Hall Mix)$suffix" 8 -metadata genre=Electronic
  library_mp3 "Afterglow Live [Disc 2]" "" 2/2 1/3 "Last Train$suffix" 6 -metadata genre=Electronic
  library_mp3 "Afterglow Live [Disc 2]" "" 2/2 2/3 "Undertow$suffix" 7 -metadata genre=Electronic
  library_mp3 "Afterglow Live [Disc 2]" "" 2/2 3/3 "Glasshouse - Reprise$suffix" 5 -metadata genre=Electronic
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
