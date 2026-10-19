#!/usr/bin/env bash
# Check a rip against the AccurateRip database.
# Usage: verify-accuraterip.sh <wav_dir> <read-disc.json>
# Output: JSON to stdout
# Exit codes: 0=checked (any verdict), 1=bad args, 2=file not found, 3=lookup failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
  cat <<'HELP'
Usage: verify-accuraterip.sh <wav_dir> <read-disc.json>

Compute the AccurateRip v1 and v2 checksums of each ripped track (01.wav,
02.wav, ... as rip-disc.sh writes them) and compare them with the rips other
people submitted for the same disc. One rip is checked; the MP3s and WAVs
both come from it, so nothing else needs checking.

Arguments:
  wav_dir         Folder of ripped WAVs
  read-disc.json  Output of read-disc.sh for the same disc, saved to a file
  --out FILE      Also write the JSON output to FILE
  --help          Show this help

Output: JSON to stdout
  {
    "status": "verified" | "partial" | "mismatch" | "not_in_database",
    "url": "http://www.accuraterip.com/...", "pressings": 1,
    "tracks": [{"n": 1, "file": "01.wav", "v1": "750e8b72", "v2": "5415d8de",
                "match": "v2", "confidence": 60}, ...],
    "matched": 14, "track_count": 14
  }
  verified: every track matched. partial: some did (the rest may be damaged,
  or a pressing nobody else submitted). mismatch: the disc is in the database
  but no track matched, most often a wrong drive read offset.
  not_in_database: nobody has submitted this disc; the rip is still secure,
  just not cross-checked.

Exit codes:
  0  Checked, whatever the verdict
  1  Bad arguments
  2  wav_dir or read-disc.json not found (a track not ripped is reported
     with "missing": true and counts as unmatched)
  3  AccurateRip could not be reached
HELP
}

# shellcheck source-path=SCRIPTDIR source=lib/out.sh
source "$SCRIPT_DIR/lib/out.sh"
with_out "${BASH_SOURCE[0]}" "$@"

ARGS=()
for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
    *) ARGS+=("$arg") ;;
  esac
done

WAV_DIR="${ARGS[0]:-}"
DISC_JSON="${ARGS[1]:-}"
if [[ -z "$WAV_DIR" || -z "$DISC_JSON" ]]; then
  echo "Error: wav_dir and read-disc.json arguments required" >&2
  show_help >&2
  exit 1
fi
if [[ ! -d "$WAV_DIR" ]]; then
  echo "Error: folder not found: $WAV_DIR" >&2
  exit 2
fi
if [[ ! -f "$DISC_JSON" ]]; then
  echo "Error: file not found: $DISC_JSON" >&2
  exit 2
fi

URL=$(jq -r '.accuraterip.url' "$DISC_JSON")
DBAR=$(mktemp "${TMPDIR:-/tmp}/dbar.XXXXXX")
trap 'rm -f "$DBAR"' EXIT

status=$(curl -sS -A "media-management/0.4" -o "$DBAR" -w '%{http_code}' "$URL" 2>/dev/null || echo 000)
case "$status" in
  200) ;;
  404) : >"$DBAR" ;;
  *)
    echo "Error: AccurateRip lookup failed (HTTP $status)" >&2
    exit 3
    ;;
esac

python3 -I - "$SCRIPT_DIR/lib" "$WAV_DIR" "$DISC_JSON" "$DBAR" "$URL" <<'PY'
import json, os, sys
sys.path.insert(0, sys.argv[1])
import accuraterip as ar

wav_dir, disc_json, dbar, url = sys.argv[2:6]
count = json.load(open(disc_json))["track_count"]
pressings = ar.parse_dbar(open(dbar, "rb").read())

tracks = []
for n in range(1, count + 1):
    name = "%02d.wav" % n
    path = os.path.join(wav_dir, name)
    if not os.path.isfile(path):
        tracks.append({"n": n, "file": name, "v1": None, "v2": None, "match": None,
                       "confidence": 0, "missing": True})
        print("Track %d: not ripped" % n, file=sys.stderr)
        continue
    v1, v2 = ar.checksums(ar.read_wav_samples(path), n == 1, n == count)
    hit = ar.match(v1, v2, n - 1, pressings)
    tracks.append({"n": n, "file": name, "v1": "%08x" % v1, "v2": "%08x" % v2,
                   "match": hit[1] if hit else None,
                   "confidence": hit[0] if hit else 0})
    print("Track %d: %s" % (n, "match (confidence %d)" % hit[0] if hit else "no match"),
          file=sys.stderr)

matched = sum(1 for t in tracks if t["match"])
if not pressings:
    status = "not_in_database"
elif matched == count:
    status = "verified"
elif matched:
    status = "partial"
else:
    status = "mismatch"
json.dump({"status": status, "url": url, "pressings": len(pressings), "tracks": tracks,
           "matched": matched, "track_count": count}, sys.stdout, indent=2)
print()
PY
