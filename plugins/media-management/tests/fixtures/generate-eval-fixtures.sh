#!/usr/bin/env bash
# Assemble a sandbox directory tree for running skill evals (evals/evals.json
# across skills/*/evals/), reusing the raw tagged audio from
# generate-fixtures.sh rather than duplicating ffmpeg calls.
#
# Usage: generate-eval-fixtures.sh [output-dir]
# Requires: ffmpeg, zip
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${1:-$SCRIPT_DIR/eval-sandbox}"

# Ensure raw tagged audio exists (track1-3.mp3, comp-track1-3.mp3, WAVs, long-track.mp3)
if [[ ! -f "$SCRIPT_DIR/track1.mp3" ]]; then
  bash "$SCRIPT_DIR/generate-fixtures.sh" "$SCRIPT_DIR"
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"/{downloads,extracted,library/"Test Artist"/"Test Album",wav-extraction,auto-import,nas-archive}

echo "Assembling eval sandbox in $OUT_DIR..." >&2

# --- extracted/Test Artist - Test Album (clean single-artist album) ---
CLEAN="$OUT_DIR/extracted/Test Artist - Test Album"
mkdir -p "$CLEAN"
cp "$SCRIPT_DIR/track1.mp3" "$SCRIPT_DIR/track2.mp3" "$SCRIPT_DIR/track3.mp3" "$CLEAN/"

# --- extracted/Foo - Bar (same album, genre stripped to isolate the missing-genre case) ---
NOGENRE="$OUT_DIR/extracted/Foo - Bar"
mkdir -p "$NOGENRE"
for i in 1 2 3; do
  ffmpeg -i "$SCRIPT_DIR/track${i}.mp3" -map_metadata 0 -metadata genre= -codec copy \
    -y "$NOGENRE/track${i}.mp3" 2>/dev/null
done

# --- extracted/Various - Comp (3 different artists, no genre — compilation fixture) ---
COMP="$OUT_DIR/extracted/Various - Comp"
mkdir -p "$COMP"
cp "$SCRIPT_DIR/comp-track1.mp3" "$SCRIPT_DIR/comp-track2.mp3" "$SCRIPT_DIR/comp-track3.mp3" "$COMP/"

# --- extracted/DJ Mix - Live Set (long track, splittable at its 2 silence gaps) ---
LONGSET="$OUT_DIR/extracted/DJ Mix - Live Set"
mkdir -p "$LONGSET"
cp "$SCRIPT_DIR/long-track.mp3" "$LONGSET/"

# --- downloads/ (ZIP pairs for select-release / process-album / cleanup) ---
DL="$OUT_DIR/downloads"
( cd "$CLEAN" && zip -q "$DL/Test Artist - Test Album.zip" ./*.mp3 )

WAVTMP=$(mktemp -d)
cp "$SCRIPT_DIR/Test Artist - Test Album - 01 Track 1.wav" \
   "$SCRIPT_DIR/Test Artist - Test Album - 02 Track 2.wav" \
   "$SCRIPT_DIR/Test Artist - Test Album - 03 Track 3.wav" "$WAVTMP/"
( cd "$WAVTMP" && zip -q "$DL/Test Artist - Test Album-2.zip" ./*.wav )
rm -rf "$WAVTMP"

# Unmatched ZIP: a standalone MP3-only release with no WAV counterpart
SOLOTMP=$(mktemp -d)
cp "$SCRIPT_DIR/track1.mp3" "$SOLOTMP/track1.mp3"
( cd "$SOLOTMP" && zip -q "$DL/Solo Artist - Lonely EP.zip" ./track1.mp3 )
rm -rf "$SOLOTMP"

# Pre-extracted folders sitting alongside the ZIPs, ready for the cleanup eval
cp -R "$CLEAN" "$DL/Test Artist - Test Album"
mkdir -p "$DL/Test Artist - Test Album-wav"
cp "$SCRIPT_DIR/Test Artist - Test Album - 01 Track 1.wav" \
   "$SCRIPT_DIR/Test Artist - Test Album - 02 Track 2.wav" \
   "$SCRIPT_DIR/Test Artist - Test Album - 03 Track 3.wav" \
   "$DL/Test Artist - Test Album-wav/"

# --- library/Test Artist/Test Album (Apple Music library shape, for archive-media mp3 mode) ---
cp "$SCRIPT_DIR/track1.mp3" "$SCRIPT_DIR/track2.mp3" "$SCRIPT_DIR/track3.mp3" \
  "$OUT_DIR/library/Test Artist/Test Album/"

# --- wav-extraction/Test Artist - Test Album-wav (for archive-media wav mode) ---
mkdir -p "$OUT_DIR/wav-extraction/Test Artist - Test Album-wav"
cp "$SCRIPT_DIR/Test Artist - Test Album - 01 Track 1.wav" \
   "$SCRIPT_DIR/Test Artist - Test Album - 02 Track 2.wav" \
   "$SCRIPT_DIR/Test Artist - Test Album - 03 Track 3.wav" \
   "$OUT_DIR/wav-extraction/Test Artist - Test Album-wav/"

# auto-import/ and nas-archive/ are left empty — destination folders for the evals to write into

echo "Done. Sandbox layout:" >&2
find "$OUT_DIR" -maxdepth 3 | sed 's|^|  |' >&2

cat >&2 <<EOF

IMPORTANT: several skills read MEDIA_MGMT_* env vars as a fallback when a
path isn't passed explicitly (e.g. cleanup-release.sh's processed/ dest).
If those are set in your real shell (they will be, on a machine actually
using this plugin), a script under test can silently ignore the sandbox
paths above and write into your real Downloads/Apple Music/NAS locations
instead. Always wrap eval script invocations with:

  bash tests/fixtures/run-isolated.sh <command> [args...]

e.g.:
  bash tests/fixtures/run-isolated.sh \\
    bash skills/cleanup/scripts/cleanup-release.sh \\
    "$OUT_DIR/downloads" "Test Artist - Test Album"
EOF
