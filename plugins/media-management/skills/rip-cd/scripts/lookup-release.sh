#!/usr/bin/env bash
# Look up the releases a disc belongs to on MusicBrainz.
# Usage: lookup-release.sh <read-disc.json>
# Output: JSON to stdout
# Exit codes: 0=success (even with no match), 1=bad args, 2=file not found, 3=lookup failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MB_API="${MEDIA_MGMT_MUSICBRAINZ_API:-https://musicbrainz.org/ws/2}"
USER_AGENT="media-management/0.4 ( https://github.com/eyelock/assistants )"

show_help() {
  cat <<'HELP'
Usage: lookup-release.sh <read-disc.json>

Look the disc up on MusicBrainz by the disc ID read-disc.sh computed. When no
release carries that exact disc ID, retry by its table of contents, which
finds releases with the same track lengths. One disc often belongs to several
releases (a 2-CD set and a box set reusing its discs), so every candidate is
returned for the user to choose from.

Each candidate is a release record: the shape rip-cd's encode step takes,
minus the choices the user makes (genre, album artist).

Arguments:
  read-disc.json  Output of read-disc.sh, saved to a file
  --out FILE      Also write the JSON output to FILE
  --help          Show this help

Output: JSON to stdout
  {
    "discid": "goxMYo...", "match": "discid" | "toc" | "none",
    "candidates": [{
      "mb_release_id": "ab3fe77a-...", "album": "Memento Mori: Mexico City",
      "artist": "Depeche Mode", "date": "2025-12-05", "year": "2025",
      "country": "XE", "label": "Columbia", "catalog_number": "...",
      "barcode": "...", "format": "CD", "disc": 1, "disc_total": 2,
      "disc_title": null, "audio_disc": 1, "audio_disc_total": 2,
      "cover_art": true,
      "discs": [{"disc": 1, "format": "CD", "tracks": [
        {"n": 1, "title": "Intro", "artist": "Depeche Mode", "seconds": 138.3}, ...]}]
    }]
  }
  "disc" is which medium of the release this CD is; "discs" lists every
  medium, so later discs of the set are known before they are ripped.
  "audio_disc"/"audio_disc_total" number the CDs among themselves, skipping
  any DVD or Blu-ray media in the set: these are the disc tags to write.

Environment:
  MEDIA_MGMT_MUSICBRAINZ_API  API base URL (default https://musicbrainz.org/ws/2)

Exit codes:
  0  Success, including no match ("match": "none")
  1  Bad arguments
  2  read-disc.json not found
  3  MusicBrainz could not be reached
HELP
}

# shellcheck source-path=SCRIPTDIR source=lib/out.sh
source "$SCRIPT_DIR/lib/out.sh"
with_out "${BASH_SOURCE[0]}" "$@"

DISC_JSON=""
for arg in "$@"; do
  case "$arg" in
    --help) show_help; exit 0 ;;
    *) DISC_JSON="$arg" ;;
  esac
done

if [[ -z "$DISC_JSON" ]]; then
  echo "Error: read-disc.json argument required" >&2
  show_help >&2
  exit 1
fi
if [[ ! -f "$DISC_JSON" ]]; then
  echo "Error: file not found: $DISC_JSON" >&2
  exit 2
fi

DISCID=$(jq -r '.musicbrainz.discid' "$DISC_JSON")
TOC=$(jq -r '.musicbrainz.toc' "$DISC_JSON")
INC="artist-credits+recordings+labels+release-groups"

TMP=$(mktemp "${TMPDIR:-/tmp}/mb-lookup.XXXXXX")
trap 'rm -f "$TMP"' EXIT

# Writes the body to $TMP, prints the HTTP status. MusicBrainz allows one
# request a second and answers 503 beyond that, so back off and retry.
fetch() {
  local status attempt
  for attempt in 1 2 3; do
    status=$(curl -sS -A "$USER_AGENT" -o "$TMP" -w '%{http_code}' "$1" 2>/dev/null || echo 000)
    [[ "$status" == "503" && $attempt -lt 3 ]] || break
    sleep $((attempt * 2))
  done
  echo "$status"
}

match="discid"
status=$(fetch "$MB_API/discid/$DISCID?fmt=json&inc=$INC")
if [[ "$status" == "404" ]]; then
  echo "No release carries disc ID $DISCID; trying its table of contents" >&2
  match="toc"
  status=$(fetch "$MB_API/discid/-?toc=$TOC&cdstubs=no&fmt=json&inc=$INC")
fi
if [[ "$status" == "404" ]]; then
  jq -n --arg discid "$DISCID" '{discid: $discid, match: "none", candidates: []}'
  exit 0
fi
if [[ "$status" != "200" ]]; then
  echo "Error: MusicBrainz lookup failed (HTTP $status)" >&2
  exit 3
fi

python3 -I - "$SCRIPT_DIR/lib" "$TMP" "$DISC_JSON" "$match" <<'PY'
import json, sys

_, body, disc_json, match = sys.argv[1:5]
data = json.load(open(body))
disc = json.load(open(disc_json))
discid = disc["musicbrainz"]["discid"]
lengths = disc["track_seconds"]


def credit(credits):
    return "".join(c.get("name", "") + c.get("joinphrase", "") for c in credits or [])


def medium_matches(medium):
    if match == "discid":
        return any(d.get("id") == discid for d in medium.get("discs", []))
    # A TOC match: same track count, every track within 3 seconds.
    tracks = medium.get("tracks", [])
    return len(tracks) == len(lengths) and all(
        t.get("length") and abs(t["length"] / 1000 - s) <= 3 for t, s in zip(tracks, lengths))


releases = data.get("releases") or ([data] if "media" in data else [])
candidates = []
for rel in releases:
    artist = credit(rel.get("artist-credit"))
    media = rel.get("media", [])
    discs = []
    for m in media:
        discs.append({
            "disc": m.get("position"),
            "format": m.get("format"),
            "title": m.get("title") or None,
            "tracks": [{
                "n": t.get("position"),
                "title": t.get("title"),
                "artist": credit(t.get("artist-credit")) or artist,
                "seconds": round(t["length"] / 1000, 1) if t.get("length") else None,
            } for t in m.get("tracks", [])],
        })
    for m in media:
        if not medium_matches(m):
            continue
        # Video discs in a box set are ripped separately, so the audio
        # discs are numbered among themselves: CD 3 and 4 of a 2 BD + 2 CD
        # box are audio discs 1/2 and 2/2.
        audio = [x.get("position") for x in media if "CD" in (x.get("format") or "CD")]
        label = (rel.get("label-info") or [{}])[0]
        date = rel.get("date") or ""
        candidates.append({
            "mb_release_id": rel["id"],
            "album": rel.get("title"),
            "artist": artist,
            "date": date or None,
            "year": date[:4] or None,
            "country": rel.get("country"),
            "label": (label.get("label") or {}).get("name"),
            "catalog_number": label.get("catalog-number"),
            "barcode": rel.get("barcode") or None,
            "release_type": (rel.get("release-group") or {}).get("primary-type"),
            "format": m.get("format"),
            "disc": m.get("position"),
            "disc_total": len(media),
            "disc_title": m.get("title") or None,
            "audio_disc": audio.index(m.get("position")) + 1 if m.get("position") in audio else None,
            "audio_disc_total": len(audio),
            "cover_art": bool((rel.get("cover-art-archive") or {}).get("front")),
            "discs": discs,
        })

json.dump({"discid": discid, "match": match if candidates else "none",
           "candidates": candidates}, sys.stdout, indent=2, ensure_ascii=False)
print()
PY
