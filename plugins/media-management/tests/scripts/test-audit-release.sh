#!/usr/bin/env bash
# audit-release's scripts against the eval sandbox's Apple Music stub, seeded
# with the half-done CD import Apple Music leaves (split per disc, no Album
# Artist, a suffix on every title, no cover): find the split, audit it,
# repair, revert, remove. Plus the import and archive changes made for CDs.
set -euo pipefail

FIXTURES_DIR="${1:-tests/fixtures}"
export PROJECT_ROOT="${2:-.}"  # read by sandbox-helper.sh
: "$FIXTURES_DIR"
# shellcheck source-path=SCRIPTDIR source=sandbox-helper.sh
source "$(dirname "$0")/sandbox-helper.sh"
A="$SKILLS/audit-release/scripts"
C="$SKILLS/rip-cd/scripts"
CD2=5e1d1c3a-7a10-4b2e-9c55-0b1d2e3f4a02
ALBUMS=(--album "Afterglow Live" --album "Afterglow Live [Disc 2]")

sandbox_build world "install_cd_stubs none" half_done_import \
  'library_mp3 "Moonrise" "Night Drive" 1/1 1/2 "Tide" 4' 'library_mp3 "MoonRise" "Night Drive" 1/1 2/2 "Ebb" 4' \
  'library_mp3 "Harbour" "Night Drive" 1/1 1/1 "Pier" 4'
W="$SB/tmp/work"
mkdir -p "$W" "$SB/home/.Trash"

check_ok() { # check_ok <audit.json> <check id> <true|false>
  [[ $(jq -r --arg id "$2" '.checks[] | select(.id == $id) | .ok' "$1") == "$3" ]] ||
    fail "audit $2 should be $3: $(jq -r --arg id "$2" '.checks[] | select(.id == $id) | .detail' "$1")"
}

# --- find-splits: the disc-suffix split and the case split; Harbour is fine.
splits=$(run_in_sandbox bash "$A/find-splits.sh" --artist "Night Drive")
[[ $(echo "$splits" | jq -c '[.splits[].reason] | sort') == '["disc_suffix","name_variant"]' ]] ||
  fail "find-splits: $(echo "$splits" | jq -c '[.splits[] | {reason, a: [.albums[].album]}]')"
echo "$splits" | jq -e '[.splits[].albums[].album] | index("Harbour") | not' >/dev/null || fail "find-splits: Harbour reported"

# --- audit: the half-done import fails exactly where it should.
run_in_sandbox bash "$A/audit-release.sh" --artist "Night Drive" "${ALBUMS[@]}" --out "$W/audit.json" >/dev/null
for id in one_album album_artist clean_titles release_id artwork nas_mp3 nas_wav rip_verified; do check_ok "$W/audit.json" "$id" false; done
for id in disc_tags complete mp3_320 files_present no_leftovers; do check_ok "$W/audit.json" "$id" true; done
[[ $(jq -r '.fixes[0].fix' "$W/audit.json") == retag ]] || fail "audit: first fix should be retag"

# --- repair: plan (read-only), apply, re-audit.
run_in_sandbox bash "$C/make-release-record.sh" --release-id "$CD2" --genre Electronic --plain-punctuation --out "$W/release.json" >/dev/null
run_in_sandbox bash "$C/fetch-cover.sh" "$CD2" "$W/cover.jpg" >/dev/null
before=$(cd "$SB" && find Music -name '*.mp3' -exec cksum {} + | sort)
run_in_sandbox bash "$A/repair-release.sh" plan --artist "Night Drive" "${ALBUMS[@]}" --release "$W/release.json" \
  --cover "$W/cover.jpg" --out "$W/plan.json" >/dev/null
[[ "$before" == "$(cd "$SB" && find Music -name '*.mp3' -exec cksum {} + | sort)" ]] || fail "plan changed files"
[[ $(jq -c '[.summary[].field]' "$W/plan.json") == '["name","album","album_artist","artwork"]' ]] ||
  fail "plan summary: $(jq -c '[.summary[].field]' "$W/plan.json")"
[[ $(run_in_sandbox bash "$A/repair-release.sh" apply "$W/plan.json" | jq .applied) -eq 6 ]] || fail "apply: expected 6"
run_in_sandbox bash "$A/audit-release.sh" --artist "Night Drive" --album "Afterglow Live" --release "$W/release.json" --out "$W/after.json" >/dev/null
for id in one_album album_artist disc_tags complete clean_titles mp3_320 release_id artwork files_present; do check_ok "$W/after.json" "$id" true; done
[[ ! -d "$SB/Music/Media.localized/Music/Night Drive/Afterglow Live [Disc 2]" ]] || fail "apply: the Disc 2 folder is still there"

# A plan with nothing left to do touches no track.
run_in_sandbox bash "$A/repair-release.sh" plan --artist "Night Drive" --album "Afterglow Live" --release "$W/release.json" --out "$W/noop.json" >/dev/null
[[ $(run_in_sandbox bash "$A/repair-release.sh" apply "$W/noop.json" | jq .applied) -eq 0 ]] || fail "no-op plan should apply to 0 tracks"

# A track whose length differs from the record's is left out, with a warning.
jq '.discs[0].tracks[0].seconds = 60' "$W/release.json" >"$W/release-long.json"
run_in_sandbox bash "$A/repair-release.sh" plan --artist "Night Drive" --album "Afterglow Live" --release "$W/release-long.json" --out "$W/warn.json" >/dev/null
[[ $(jq '.warnings | length' "$W/warn.json") -eq 1 && $(jq '.tracks | length' "$W/warn.json") -eq 5 ]] ||
  fail "length mismatch: expected 1 warning and 5 planned tracks"

# --- revert: split again, titles and blank Album Artist back, cover removed.
run_in_sandbox bash "$A/repair-release.sh" revert "$W/plan.json" >/dev/null
run_in_sandbox bash "$A/audit-release.sh" --artist "Night Drive" "${ALBUMS[@]}" --out "$W/reverted.json" >/dev/null
for id in one_album album_artist clean_titles artwork; do check_ok "$W/reverted.json" "$id" false; done

# --- remove-tracks: a dry run changes nothing; --confirm removes only the
# snapshot's tracks and moves their files to the Trash.
run_in_sandbox bash "$A/music-tracks.sh" --artist "Night Drive" --album "Afterglow Live [Disc 2]" --out "$W/snapshot.json" >/dev/null
dry=$(run_in_sandbox bash "$A/remove-tracks.sh" "$W/snapshot.json")
[[ $(echo "$dry" | jq .removed) -eq 0 && $(echo "$dry" | jq '.tracks | length') -eq 3 ]] || fail "remove dry run"
grep -q 'DESTRUCTIVE' "$SB/.eval/stub-calls.log" && fail "dry run made a destructive call"
[[ $(run_in_sandbox bash "$A/remove-tracks.sh" "$W/snapshot.json" --disc 1 | jq '.tracks | length') -eq 0 ]] ||
  fail "remove --disc 1: the snapshot holds only disc 2 tracks"
rc=0
run_in_sandbox bash "$A/remove-tracks.sh" "$W/snapshot.json" --disc 2 --confirm >/dev/null 2>&1 || rc=$?
[[ $rc -eq 1 ]] || fail "remove --confirm without a token should be refused (rc=$rc)"
rc=0
run_in_sandbox bash "$A/remove-tracks.sh" "$W/snapshot.json" --disc 2 --confirm deadbeef >/dev/null 2>&1 || rc=$?
[[ $rc -eq 1 ]] || fail "remove --confirm with a wrong token should be refused (rc=$rc)"
grep -q 'DESTRUCTIVE' "$SB/.eval/stub-calls.log" && fail "a refused confirm still made a destructive call"
token=$(run_in_sandbox bash "$A/remove-tracks.sh" "$W/snapshot.json" --disc 2 | jq -r .confirm_token)
done=$(run_in_sandbox bash "$A/remove-tracks.sh" "$W/snapshot.json" --disc 2 --confirm "$token")
[[ $(echo "$done" | jq .removed) -eq 3 && $(echo "$done" | jq .trashed) -eq 3 ]] || fail "remove: $(echo "$done" | jq -c '{removed, trashed, errors}')"
[[ $(find "$SB/home/.Trash" -name '*.mp3' | wc -l) -eq 3 ]] || fail "remove: files not in the Trash"
left=$(run_in_sandbox bash "$A/music-tracks.sh" --artist "Night Drive" | jq -c '[.groups[] | .album] | sort')
[[ "$left" == '["Afterglow Live","Harbour","MoonRise","Moonrise"]' ]] || fail "remove: library left with $left"

# --- import-mp3s --wait: Apple Music (the stub) picks the files up.
sandbox_build world "install_cd_stubs 1" "disc_done 1 encoded"
work="$SB/tmp/media-management/cd-rip-Night Drive - Afterglow Live"
imp="$SB/Music/Media.localized/Automatically Add to Music.localized"
out=$(run_in_sandbox bash "$SKILLS/import-to-apple-music/scripts/import-mp3s.sh" "$work/disc1/mp3" "$imp" --wait 30 2>/dev/null)
[[ $(echo "$out" | jq .picked_up) == true && $(echo "$out" | jq '.not_added | length') -eq 0 ]] ||
  fail "import --wait: $(echo "$out" | jq -c '{picked_up, not_added}')"
[[ $(run_in_sandbox bash "$SKILLS/import-to-apple-music/scripts/import-mp3s.sh" "$work/disc1/mp3" "$imp" 2>/dev/null | jq .picked_up) == null ]] ||
  fail "import without --wait should report picked_up null"

# --- archive-media: disc 2 added to a NAS folder that holds disc 1.
sandbox_build world "install_cd_stubs 1" "disc_done 1 archive" "disc_done 2"
nas="$SB/NAS/to_nas/wav/Night Drive/Afterglow Live"
out=$(run_in_sandbox bash "$SKILLS/archive-media/scripts/archive-files.sh" wav \
  "$SB/tmp/media-management/cd-rip-Night Drive - Afterglow Live/disc2/wav" "$nas" 2>/dev/null)
[[ $(echo "$out" | jq -c '[.source_count, .dest_count, .verified]') == '[3,6,true]' ]] ||
  fail "archive disc 2: $(echo "$out" | jq -c '[.source_count, .dest_count, .verified]')"
[[ -f "$nas/2-01 Last Train.wav" && -f "$nas/1-01 Dusk.wav" ]] || fail "archive disc 2: names not kept"
[[ $(jq -r '.discs[1].accuraterip' "$nas/release.json") == verified ]] || fail "archive disc 2: release.json not updated"

echo "All audit-release tests passed"
