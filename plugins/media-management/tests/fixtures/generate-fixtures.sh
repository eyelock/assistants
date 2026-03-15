#!/usr/bin/env bash
# Generate test audio fixtures for script tests.
# Usage: generate-fixtures.sh [output-dir]
# Requires: ffmpeg

set -euo pipefail

FIXTURES_DIR="${1:-$(dirname "$0")}"
mkdir -p "$FIXTURES_DIR"

TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

echo "Generating test fixtures in $FIXTURES_DIR..." >&2

# Single artist album (3 tracks)
for i in 1 2 3; do
  ffmpeg -f lavfi -i anullsrc=r=44100:cl=stereo -t 3 \
    -metadata title="Track ${i}" -metadata artist="Test Artist" \
    -metadata album="Test Album" -metadata track="${i}" \
    -metadata genre="Electronic" \
    -c:a libmp3lame -q:a 2 -y "$FIXTURES_DIR/track${i}.mp3" 2>/dev/null
done

# Compilation album (3 tracks, different artists)
for i in 1 2 3; do
  ffmpeg -f lavfi -i anullsrc=r=44100:cl=stereo -t 3 \
    -metadata title="Comp Track ${i}" -metadata artist="Artist ${i}" \
    -metadata album="Various Hits" -metadata track="${i}" \
    -c:a libmp3lame -q:a 2 -y "$FIXTURES_DIR/comp-track${i}.mp3" 2>/dev/null
done

# WAV files with vendor naming
for i in 1 2 3; do
  ffmpeg -f lavfi -i anullsrc=r=44100:cl=stereo -t 3 \
    -metadata title="Track ${i}" -metadata artist="Test Artist" \
    -metadata album="Test Album" -metadata track="${i}" \
    -y "$FIXTURES_DIR/Test Artist - Test Album - 0${i} Track ${i}.wav" 2>/dev/null
done

# Track with spaces and unicode in filename
ffmpeg -f lavfi -i anullsrc=r=44100:cl=stereo -t 3 \
  -metadata title="Melody A.M." -metadata artist="Röyksopp" \
  -metadata album="Melody A.M." -metadata track="1" \
  -c:a libmp3lame -q:a 2 -y "$FIXTURES_DIR/Röyksopp - Melody A.M..mp3" 2>/dev/null

# Track with no metadata
ffmpeg -f lavfi -i anullsrc=r=44100:cl=stereo -t 3 \
  -c:a libmp3lame -q:a 2 -y "$FIXTURES_DIR/no-metadata.mp3" 2>/dev/null

# Long track for split testing: tone-silence-tone-silence-tone (~15s total)
# All segments must be stereo for concat to work
ffmpeg -f lavfi -i "sine=frequency=440:r=44100:d=5" -ac 2 -y "$TEST_TMPDIR/seg1.wav" 2>/dev/null
ffmpeg -f lavfi -i anullsrc=r=44100:cl=stereo -t 1 -y "$TEST_TMPDIR/seg2.wav" 2>/dev/null
ffmpeg -f lavfi -i "sine=frequency=880:r=44100:d=5" -ac 2 -y "$TEST_TMPDIR/seg3.wav" 2>/dev/null
ffmpeg -f lavfi -i anullsrc=r=44100:cl=stereo -t 1 -y "$TEST_TMPDIR/seg4.wav" 2>/dev/null
ffmpeg -f lavfi -i "sine=frequency=660:r=44100:d=3" -ac 2 -y "$TEST_TMPDIR/seg5.wav" 2>/dev/null

cat > "$TEST_TMPDIR/concat.txt" <<EOF
file '${TEST_TMPDIR}/seg1.wav'
file '${TEST_TMPDIR}/seg2.wav'
file '${TEST_TMPDIR}/seg3.wav'
file '${TEST_TMPDIR}/seg4.wav'
file '${TEST_TMPDIR}/seg5.wav'
EOF

ffmpeg -f concat -safe 0 -i "$TEST_TMPDIR/concat.txt" \
  -metadata title="Long Mix" -metadata artist="DJ Test" \
  -metadata album="Long Album" -metadata track="1" \
  -c:a libmp3lame -q:a 2 -y "$FIXTURES_DIR/long-track.mp3" 2>/dev/null

echo "Fixtures generated successfully." >&2
