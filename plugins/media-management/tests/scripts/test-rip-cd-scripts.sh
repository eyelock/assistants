#!/usr/bin/env bash
# rip-cd's scripts end to end against the eval sandbox's stub drive and web
# (evals/files/cd-stub.sh): identify, look up, record, rip, verify, encode.
set -euo pipefail

FIXTURES_DIR="${1:-tests/fixtures}"
export PROJECT_ROOT="${2:-.}"  # read by sandbox-helper.sh
: "$FIXTURES_DIR"
# shellcheck source-path=SCRIPTDIR source=sandbox-helper.sh
source "$(dirname "$0")/sandbox-helper.sh"
S="$SKILLS/rip-cd/scripts"
BOX=5e1d1c3a-7a10-4b2e-9c55-0b1d2e3f4a01
CD2=5e1d1c3a-7a10-4b2e-9c55-0b1d2e3f4a02

sandbox_build world "install_cd_stubs 1"
W="$SB/tmp/work"
mkdir -p "$W"

# --- check-deps: the stub drive answers --version, so all is well; a broken
# cd-paranoia (it is there but will not run) is reported, with reinstall.
run_in_sandbox bash "$S/check-deps.sh" >/dev/null || fail "check-deps should pass with every tool working"
printf '#!/bin/sh\nexit 134\n' >"$TEST_TMPDIR/cd-paranoia" && chmod +x "$TEST_TMPDIR/cd-paranoia"
rc=0
out=$(PATH="$TEST_TMPDIR:$PATH" bash "$S/check-deps.sh" 2>/dev/null) || rc=$?
[[ $rc -eq 3 ]] || fail "check-deps: broken cd-paranoia should exit 3, got $rc"
[[ $(echo "$out" | jq -r .install_command) == "brew reinstall libcdio-paranoia" ]] ||
  fail "check-deps: expected 'brew reinstall libcdio-paranoia', got $(echo "$out" | jq -r .install_command)"

# --- work-dir: under work_dir from config, never Downloads.
wd=$(run_in_sandbox bash "$S/work-dir.sh" "cd-rip-A: b/c" | jq -r .work_dir)
[[ "$wd" == "$SB/tmp/media-management/cd-rip-A_ b_c" && -d "$wd" ]] || fail "work-dir: got $wd"

# --- read-disc (not mounted: TOC from cd-paranoia), with --out.
run_in_sandbox bash "$S/read-disc.sh" --out "$W/disc.json" >/dev/null || fail "read-disc failed"
[[ $(jq .track_count "$W/disc.json") -eq 3 ]] || fail "read-disc: expected 3 tracks"
[[ $(jq -c .toc.offsets "$W/disc.json") == "[0,525,975]" ]] || fail "read-disc: offsets $(jq -c .toc.offsets "$W/disc.json")"
[[ ! -e "$W/disc.json.partial" ]] || fail "--out left a partial file"
(cd "$SB" && echo none >.eval/cd/disc)
rc=0
run_in_sandbox bash "$S/read-disc.sh" --out "$W/none.json" >/dev/null 2>&1 || rc=$?
[[ $rc -eq 2 && ! -e "$W/none.json" ]] || fail "read-disc: no disc should exit 2 and write nothing (rc=$rc)"
(cd "$SB" && echo 1 >.eval/cd/disc)

# --- lookup-release: the disc is in two releases; the box's DVD is skipped
# when numbering the audio discs.
run_in_sandbox bash "$S/lookup-release.sh" "$W/disc.json" --out "$W/lookup.json" >/dev/null || fail "lookup failed"
[[ $(jq -r .match "$W/lookup.json") == discid ]] || fail "lookup: expected a disc ID match"
[[ $(jq '.candidates | length' "$W/lookup.json") -eq 2 ]] || fail "lookup: expected 2 candidates"
box=$(jq -c --arg id "$BOX" '.candidates[] | select(.mb_release_id == $id) | [.disc, .disc_total, .audio_disc, .audio_disc_total]' "$W/lookup.json")
[[ "$box" == "[2,3,1,2]" ]] || fail "lookup: box set should be medium 2 of 3, audio disc 1 of 2, got $box"
# An unknown disc: the TOC fallback finds nothing either.
jq '.musicbrainz.discid = "unknownDiscId000000000000000-"' "$W/disc.json" >"$W/unknown.json"
[[ $(run_in_sandbox bash "$S/lookup-release.sh" "$W/unknown.json" 2>/dev/null | jq -r .match) == none ]] ||
  fail "lookup: unknown disc should give match none"

# --- make-release-record: plain punctuation, title override checks.
run_in_sandbox bash "$S/make-release-record.sh" --release-id "$CD2" --genre Electronic \
  --plain-punctuation --discid "1=$(jq -r .musicbrainz.discid "$W/disc.json")" --out "$W/release.json" >/dev/null ||
  fail "make-release-record failed"
[[ $(jq -r '.discs[1].tracks[2].title' "$W/release.json") == "Glasshouse - Reprise" ]] ||
  fail "plain punctuation: got $(jq -r '.discs[1].tracks[2].title' "$W/release.json")"
[[ $(jq -r '[.album_artist, .genre, (.disc_total|tostring)] | join("|")' "$W/release.json") == "Night Drive|Electronic|2" ]] ||
  fail "record: album artist, genre or disc total wrong"
echo '{"1": ["only one"]}' >"$W/bad-titles.json"
rc=0
run_in_sandbox bash "$S/make-release-record.sh" --release-id "$CD2" --genre X --titles-from "$W/bad-titles.json" >/dev/null 2>&1 || rc=$?
[[ $rc -eq 1 ]] || fail "titles-from with the wrong count should exit 1, got $rc"

# --- fetch-cover: square cover; a release without one exits 2.
run_in_sandbox bash "$S/fetch-cover.sh" "$CD2" "$W/cover.jpg" >/dev/null || fail "fetch-cover failed"
rc=0
run_in_sandbox bash "$S/fetch-cover.sh" 00000000-0000-0000-0000-000000000000 "$W/none.jpg" >/dev/null 2>&1 || rc=$?
[[ $rc -eq 2 ]] || fail "fetch-cover: no cover should exit 2, got $rc"

# --- rip-disc: offset passed through, disc unmounted then remounted.
run_in_sandbox bash "$S/rip-disc.sh" "$W/rip" --offset 6 --out "$W/rip.json" >/dev/null 2>&1 || fail "rip failed"
[[ $(jq '.tracks | length' "$W/rip.json") -eq 3 && $(jq '.failed | length' "$W/rip.json") -eq 0 ]] || fail "rip: expected 3 clean tracks"
grep -q 'cd-paranoia \[disc 1\].* -O 6 ' "$SB/.eval/stub-calls.log" || fail "rip: cd-paranoia not called with -O 6"
grep -q 'diskutil.*unmountDisk' "$SB/.eval/stub-calls.log" || fail "rip: disc not unmounted"
[[ $(grep -c 'diskutil.*mountDisk' "$SB/.eval/stub-calls.log") -ge 2 ]] || fail "rip: disc not remounted"

# --- verify-accuraterip: verified with the right offset, mismatch with the
# wrong one, not_in_database without an entry, and a missing track counted.
v=$(run_in_sandbox bash "$S/verify-accuraterip.sh" "$W/rip" "$W/disc.json" 2>/dev/null)
[[ $(echo "$v" | jq -r .status) == verified && $(echo "$v" | jq .matched) -eq 3 ]] || fail "verify: expected verified 3/3, got $(echo "$v" | jq -c '{status, matched}')"
run_in_sandbox bash "$S/rip-disc.sh" "$W/rip0" --offset 0 >/dev/null 2>&1
[[ $(run_in_sandbox bash "$S/verify-accuraterip.sh" "$W/rip0" "$W/disc.json" 2>/dev/null | jq -r .status) == mismatch ]] ||
  fail "verify: offset 0 should be a mismatch"
mkdir -p "$W/rip2" && cp "$W/rip/01.wav" "$W/rip/02.wav" "$W/rip2/"
v=$(run_in_sandbox bash "$S/verify-accuraterip.sh" "$W/rip2" "$W/disc.json" 2>/dev/null)
[[ $(echo "$v" | jq -r .status) == partial && $(echo "$v" | jq '.tracks[2].missing') == true ]] || fail "verify: a missing track should make it partial"
mv "$SB"/.eval/web/dBAR-* "$TEST_TMPDIR/"
[[ $(run_in_sandbox bash "$S/verify-accuraterip.sh" "$W/rip" "$W/disc.json" 2>/dev/null | jq -r .status) == not_in_database ]] ||
  fail "verify: no AccurateRip entry should be not_in_database"
mv "$TEST_TMPDIR"/dBAR-* "$SB/.eval/web/"

# --- update-record: verdict, ID and title, in the record and its copies.
mkdir -p "$W/disc1/wav" && cp "$W/release.json" "$W/disc1/wav/release.json"
run_in_sandbox bash "$S/update-record.sh" "$W/release.json" --disc 1 --accuraterip verified \
  --title '3=Overpass: Hall/Mix "12″"' >/dev/null || fail "update-record failed"
[[ $(jq -r '.discs[0].accuraterip' "$W/disc1/wav/release.json") == verified ]] || fail "update-record: copy not updated"
rc=0
run_in_sandbox bash "$S/update-record.sh" "$W/release.json" --disc 1 --title "9=x" >/dev/null 2>&1 || rc=$?
[[ $rc -eq 1 ]] || fail "update-record: a track that does not exist should exit 1"

# --- encode-release: names, tags, cover, untouched PCM.
run_in_sandbox bash "$S/encode-release.sh" "$W/rip" "$W/release.json" 1 "$W/out" --cover "$W/cover.jpg" >/dev/null 2>&1 ||
  fail "encode failed"
names=$(find "$W/out/mp3" -name '*.mp3' -exec basename {} \; | sort | tr '\n' '|')
[[ "$names" == '1-01 Dusk.mp3|1-02 Neon Rain.mp3|1-03 Overpass_ Hall_Mix _12″_.mp3|' ]] ||
  fail "encode: MP3 names $names"
tags=$(ffprobe -v quiet -show_format -show_streams -of json "$W/out/mp3/1-01 Dusk.mp3")
[[ $(echo "$tags" | jq -r '.format.tags | [.album, .album_artist, .disc, .track, .genre, .["MusicBrainz Album Id"]] | join("|")') == \
  "Afterglow Live|Night Drive|1/2|1/3|Electronic|$CD2" ]] || fail "encode: tags $(echo "$tags" | jq -c .format.tags)"
[[ $(echo "$tags" | jq '[.streams[] | select(.disposition.attached_pic == 1)] | length') -eq 1 ]] || fail "encode: no embedded cover"
[[ $(echo "$tags" | jq '(.format.bit_rate | tonumber) > 300000') == true ]] || fail "encode: not 320 kbps"
cmp -s <(ffmpeg -v quiet -i "$W/rip/02.wav" -f s16le -) <(ffmpeg -v quiet -i "$W/out/wav/1-02 Neon Rain.wav" -f s16le -) ||
  fail "encode: WAV audio differs from the rip"
[[ -f "$W/out/wav/release.json" && -f "$W/out/wav/cover.jpg" ]] || fail "encode: release.json or cover.jpg missing from wav/"
run_in_sandbox bash "$S/encode-release.sh" "$W/rip" "$W/release.json" 1 "$W/wavonly" --wav-only >/dev/null 2>&1 ||
  fail "encode --wav-only failed"
[[ ! -d "$W/wavonly/mp3" && $(find "$W/wavonly/wav" -name '*.wav' | wc -l) -eq 3 ]] || fail "encode --wav-only: wrong output"

# --- eject-disc.
run_in_sandbox bash "$S/eject-disc.sh" >/dev/null || fail "eject failed"
[[ $(cat "$SB/.eval/cd/disc") == none ]] || fail "eject: disc still in the drive"

echo "All rip-cd script tests passed"
