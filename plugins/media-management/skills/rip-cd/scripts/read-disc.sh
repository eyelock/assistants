#!/usr/bin/env bash
# Identify the audio CD in the drive from its table of contents.
# Usage: read-disc.sh [--device /dev/diskN] [--toc-plist FILE] [--titles-dir DIR]
# Output: JSON to stdout
# Exit codes: 0=success, 1=bad args, 2=no disc, 3=TOC could not be read

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
  cat <<'HELP'
Usage: read-disc.sh [--device /dev/diskN] [--toc-plist FILE] [--titles-dir DIR]

Find the audio CD in the optical drive and read its table of contents: track
start sectors and lead-out. From those it computes the MusicBrainz disc ID
and the AccurateRip IDs locally; nothing is looked up online here.

The TOC comes from the .TOC.plist macOS writes on the mounted disc, or, when
the disc is not mounted, from `cd-paranoia -Q`. Track titles macOS shows on
the mounted disc (from its own online lookup) are returned too, with any
bracketed suffix that repeats across tracks, so a disc MusicBrainz does not
know can still be named cleanly.

Options:
  --device DEV      Disc device (default: the one `drutil status` reports)
  --toc-plist FILE  Read this .TOC.plist instead of the drive's
  --titles-dir DIR  Read track titles from these "N Title.aiff" names
  --out FILE        Also write the JSON output to FILE
  --help            Show this help

Output: JSON to stdout
  {
    "device": "/dev/disk4", "mount_point": "/Volumes/M [Disc 1]",
    "volume_name": "M [Disc 1]", "track_count": 14,
    "toc": {"first": 1, "last": 14, "offsets": [0, 10371, ...], "leadout": 315136},
    "track_seconds": [138.28, ...],
    "musicbrainz": {"discid": "goxMYo...", "toc": "1+14+315286+150+..."},
    "accuraterip": {"id1": "...", "id2": "...", "cddb": "...", "url": "http://..."},
    "mac_titles": {"titles": [...], "repeated_suffixes": [{"suffix": "(live at ...)",
                   "tracks": [1, 2, ...], "count": 14}], "stripped": [...]}
  }

Exit codes:
  0  Success
  1  Bad arguments
  2  No disc in the drive
  3  The table of contents could not be read
HELP
}

# shellcheck source-path=SCRIPTDIR source=lib/out.sh
source "$SCRIPT_DIR/lib/out.sh"
with_out "${BASH_SOURCE[0]}" "$@"

DEVICE=""
TOC_PLIST=""
TITLES_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) show_help; exit 0 ;;
    --device) DEVICE="${2:-}"; shift 2 ;;
    --toc-plist) TOC_PLIST="${2:-}"; shift 2 ;;
    --titles-dir) TITLES_DIR="${2:-}"; shift 2 ;;
    *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

MOUNT_POINT=""
if [[ -z "$TOC_PLIST" ]]; then
  if [[ -z "$DEVICE" ]]; then
    status=$(drutil status 2>/dev/null || true)
    if echo "$status" | grep -q "No Media Inserted" || [[ -z "$status" ]]; then
      echo "Error: no disc in the drive" >&2
      exit 2
    fi
    DEVICE=$(echo "$status" | sed -n 's/.*Name: *\(\/dev\/disk[0-9]*\).*/\1/p' | head -1)
    if [[ -z "$DEVICE" ]]; then
      echo "Error: no disc in the drive" >&2
      exit 2
    fi
  fi
  MOUNT_POINT=$(mount | awk -v dev="$DEVICE" '$1 == dev && /cddafs/ {sub(/^[^ ]+ on /, ""); sub(/ \(cddafs.*$/, ""); print}' | head -1)
  if [[ -n "$MOUNT_POINT" && -f "$MOUNT_POINT/.TOC.plist" ]]; then
    TOC_PLIST="$MOUNT_POINT/.TOC.plist"
  fi
  [[ -z "$TITLES_DIR" && -n "$MOUNT_POINT" ]] && TITLES_DIR="$MOUNT_POINT"
fi

PARANOIA_TOC=""
if [[ -z "$TOC_PLIST" ]]; then
  # Not mounted (or no plist): ask the drive. cd-paranoia prints the table to stderr.
  if ! PARANOIA_TOC=$(cd-paranoia -d "${DEVICE/disk/rdisk}" -Q 2>&1); then
    echo "Error: could not read the table of contents from $DEVICE" >&2
    echo "$PARANOIA_TOC" | tail -3 >&2
    exit 3
  fi
fi

TITLES=()
if [[ -n "$TITLES_DIR" && -d "$TITLES_DIR" ]]; then
  # macOS shows "/" in a title as ":" in the file name.
  while IFS= read -r f; do TITLES+=("$f"); done < <(
    find "$TITLES_DIR" -maxdepth 1 -iname '*.aiff' -type f -exec basename {} \; |
      sed -E 's/\.aiff$//' | sort -n | sed -E 's/^[0-9]+ //; s/:/\//g')
fi

TITLE_LINES=$(printf '%s\n' "${TITLES[@]:-}")
python3 -I - "$SCRIPT_DIR/lib" "$TOC_PLIST" "$PARANOIA_TOC" "$DEVICE" "$MOUNT_POINT" \
  "$TITLE_LINES" <<'PY' || exit 3
import json, os, sys
sys.path.insert(0, sys.argv[1])
import disc

plist, paranoia, device, mount, title_lines = sys.argv[2:7]
try:
    toc = disc.toc_from_plist(plist) if plist else disc.toc_from_paranoia(paranoia)
except Exception as e:
    print("Error: could not read the table of contents: %s" % e, file=sys.stderr)
    sys.exit(3)

titles = [t for t in title_lines.splitlines() if t]
suffixes = disc.repeated_suffixes(titles)
json.dump({
    "device": device or None,
    "mount_point": mount or None,
    "volume_name": os.path.basename(mount) if mount else None,
    "track_count": len(toc["offsets"]),
    "toc": toc,
    "track_seconds": [round(s / 75, 2) for s in disc.track_lengths(toc)],
    "musicbrainz": {"discid": disc.musicbrainz_discid(toc), "toc": disc.musicbrainz_toc(toc)},
    "accuraterip": disc.accuraterip_ids(toc),
    "mac_titles": {
        "titles": titles,
        "repeated_suffixes": suffixes,
        "stripped": disc.strip_suffixes(titles, {s["suffix"] for s in suffixes}),
    },
}, sys.stdout, indent=2, ensure_ascii=False)
print()
PY
