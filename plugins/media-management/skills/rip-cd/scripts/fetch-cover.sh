#!/usr/bin/env bash
# Download a MusicBrainz release's front cover from the Cover Art Archive.
# Usage: fetch-cover.sh <mb_release_id> <dest.jpg> [--no-pad]
# Output: JSON to stdout
# Exit codes: 0=success, 1=bad args, 2=release has no front cover, 3=download or ffmpeg error

set -euo pipefail

CAA="${MEDIA_MGMT_COVERART_API:-https://coverartarchive.org}"

show_help() {
  cat <<'HELP'
Usage: fetch-cover.sh <mb_release_id> <dest.jpg> [--no-pad]

Download the release's primary front cover (1200px when available) and save
it as a JPEG. Apple Music shows albums as squares, so a cover that is not
square is padded to a square with its own edge colour rather than cropped:
nothing on the cover is lost. Look at the image before embedding it; the
Archive's scans are sometimes photos of a shrink-wrapped box.

Use this instead of letting Apple Music find artwork: its guesses for CD
imports are often for a different album entirely, and it keeps them in its
own cache rather than in the files.

Arguments:
  mb_release_id  MusicBrainz release ID
  dest.jpg       Where to save the cover
  --no-pad       Keep the image's own shape
  --help         Show this help

Environment:
  MEDIA_MGMT_COVERART_API  Cover Art Archive base URL (default https://coverartarchive.org)

Output: JSON to stdout
  {"file": "/path/cover.jpg", "source": "https://coverartarchive.org/...",
   "width": 599, "height": 599, "original": {"width": 599, "height": 553},
   "padded": true}

Exit codes:
  0  Success
  1  Bad arguments
  2  The release has no front cover in the Archive
  3  Download or image processing failed
HELP
}

ARGS=()
PAD=true
for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
    --no-pad) PAD=false ;;
    *) ARGS+=("$arg") ;;
  esac
done

ID="${ARGS[0]:-}"
DEST="${ARGS[1]:-}"
if [[ -z "$ID" || -z "$DEST" ]]; then
  echo "Error: mb_release_id and dest.jpg arguments required" >&2
  show_help >&2
  exit 1
fi

TMP=$(mktemp "${TMPDIR:-/tmp}/cover.XXXXXX")
trap 'rm -f "$TMP"' EXIT

source_url=""
for size in front-1200 front; do
  # The Archive redirects to archive.org, which fails now and then: retry.
  for attempt in 1 2 3; do
    status=$(curl -sSL -o "$TMP" -w '%{http_code}' "$CAA/release/$ID/$size" 2>/dev/null || echo 000)
    [[ "$status" =~ ^(5..|000)$ && $attempt -lt 3 ]] || break
    sleep $((attempt * 2))
  done
  if [[ "$status" == "200" ]]; then
    source_url="$CAA/release/$ID/$size"
    break
  fi
  if [[ "$status" != "404" ]]; then
    echo "Error: Cover Art Archive download failed (HTTP $status)" >&2
    exit 3
  fi
done
if [[ -z "$source_url" ]]; then
  echo "Error: the release has no front cover in the Cover Art Archive" >&2
  exit 2
fi

dims() {
  ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$1"
}
IFS=, read -r w h <<<"$(dims "$TMP")"
if [[ -z "${w:-}" || -z "${h:-}" ]]; then
  echo "Error: the download is not an image" >&2
  exit 3
fi

mkdir -p "$(dirname "$DEST")"
padded=false
if [[ "$PAD" == true && "$w" -ne "$h" ]]; then
  side=$((w > h ? w : h))
  side=$(((side + 1) / 2 * 2))  # JPEG chroma subsampling needs even sides
  # Pad with the colour of the image's top-left corner (a 4x4 average:
  # a single JPEG pixel is noisy).
  colour=$(ffmpeg -v error -i "$TMP" -vf "format=rgb24,crop=4:4:0:0,scale=1:1" -frames:v 1 \
    -f rawvideo - 2>/dev/null | od -An -tx1 | tr -d ' \n' || true)
  colour="${colour:-000000}"
  if ! ffmpeg -v error -y -i "$TMP" \
    -vf "pad=$side:$side:(ow-iw)/2:(oh-ih)/2:color=0x$colour" -q:v 2 "$DEST" </dev/null; then
    echo "Error: could not pad the cover" >&2
    exit 3
  fi
  padded=true
else
  if ! ffmpeg -v error -y -i "$TMP" -q:v 2 "$DEST" </dev/null; then
    echo "Error: could not save the cover as JPEG" >&2
    exit 3
  fi
fi

IFS=, read -r fw fh <<<"$(dims "$DEST")"
jq -n --arg file "$DEST" --arg source "$source_url" --argjson w "$fw" --argjson h "$fh" \
  --argjson ow "$w" --argjson oh "$h" --argjson padded "$padded" \
  '{file: $file, source: $source, width: $w, height: $h, original: {width: $ow, height: $oh}, padded: $padded}'
