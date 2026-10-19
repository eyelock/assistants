#!/usr/bin/env bash
# Build the release record (release.json) for a MusicBrainz release from the
# answers the user confirmed.
# Usage: make-release-record.sh --release-id ID --genre GENRE [options]
# Output: JSON to stdout
# Exit codes: 0=success, 1=bad args, 3=lookup failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MB_API="${MEDIA_MGMT_MUSICBRAINZ_API:-https://musicbrainz.org/ws/2}"
USER_AGENT="media-management/0.4 ( https://github.com/eyelock/assistants )"

show_help() {
  cat <<'HELP'
Usage: make-release-record.sh --release-id ID --genre GENRE [options]

Fetch one MusicBrainz release and write the record every later step reads:
encode-release.sh tags from it, archive-media keeps it beside the WAVs, and
audit-release.sh and repair-release.sh check Apple Music against it. Only
the audio CDs of the release are kept and numbered 1..N, so a box set's
Blu-rays do not count towards the disc total.

Options:
  --release-id ID     MusicBrainz release ID (a lookup-release.sh candidate)
  --genre GENRE       Genre the user chose (never guessed)
  --album NAME        Album title, if the user wants other than MusicBrainz's
  --album-artist NAME Album Artist (default: the release's artist credit;
                      "Various Artists" for a compilation)
  --compilation       Mark as a compilation
  --plain-punctuation Turn typographic punctuation in titles into what a
                      keyboard types, so searching the library finds them:
                      curly quotes and primes (’ “ ” 12″) into ' and ", and
                      Unicode hyphens and dashes ("True Faith‐94",
                      "mix – alternate") into "-"
  --discid N=ID       MusicBrainz disc ID of audio disc N, when ripped; repeatable
  --titles-from FILE  Use these titles instead of MusicBrainz's: JSON
                      {"1": ["Intro", ...], "2": [...]} keyed by audio disc.
                      MusicBrainz leaves versions ("Zephyr Mix") out of titles,
                      so the user may prefer the disc's own titles, cleaned
  --out FILE          Also write the JSON output to FILE
  --help              Show this help

Output: JSON to stdout (the release record)
  {"mb_release_id": "...", "album": "...", "album_artist": "...", "artist": "...",
   "year": "2025", "genre": "...", "compilation": false, "disc_total": 2,
   "label": "...", "catalog_number": "...", "cover_art": true,
   "discs": [{"disc": 1, "medium": 3, "mb_discid": "...", "accuraterip": null,
              "tracks": [{"n": 1, "title": "Intro", "artist": "Depeche Mode",
                          "seconds": 138.3}, ...]}]}
  "medium" is the disc's position in the full release; "accuraterip" is
  filled in by the skill once the disc's rip is verified.

Environment:
  MEDIA_MGMT_MUSICBRAINZ_API  API base URL (default https://musicbrainz.org/ws/2)

Exit codes:
  0  Success
  1  Bad arguments
  3  MusicBrainz could not be reached, or has no such release
HELP
}

# shellcheck source-path=SCRIPTDIR source=lib/out.sh
source "$SCRIPT_DIR/lib/out.sh"
with_out "${BASH_SOURCE[0]}" "$@"

RELEASE_ID=""
GENRE=""
ALBUM=""
ALBUM_ARTIST=""
COMPILATION=false
STRAIGHT=false
DISCIDS="{}"
TITLES_FROM=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) show_help; exit 0 ;;
    --release-id) RELEASE_ID="${2:-}"; shift 2 ;;
    --genre) GENRE="${2:-}"; shift 2 ;;
    --album) ALBUM="${2:-}"; shift 2 ;;
    --album-artist) ALBUM_ARTIST="${2:-}"; shift 2 ;;
    --compilation) COMPILATION=true; shift ;;
    --plain-punctuation) STRAIGHT=true; shift ;;
    --titles-from) TITLES_FROM="${2:-}"; shift 2 ;;
    --discid)
      DISCIDS=$(echo "$DISCIDS" | jq --arg k "${2%%=*}" --arg v "${2#*=}" '. + {($k): $v}')
      shift 2
      ;;
    *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$RELEASE_ID" || -z "$GENRE" ]]; then
  echo "Error: --release-id and --genre required" >&2
  show_help >&2
  exit 1
fi

TMP=$(mktemp "${TMPDIR:-/tmp}/mb-release.XXXXXX")
trap 'rm -f "$TMP"' EXIT
# MusicBrainz allows one request a second and answers 503 beyond that.
for attempt in 1 2 3; do
  status=$(curl -sS -A "$USER_AGENT" -o "$TMP" -w '%{http_code}' \
    "$MB_API/release/$RELEASE_ID?fmt=json&inc=artist-credits+recordings+labels+discids" 2>/dev/null || echo 000)
  [[ "$status" == "503" && $attempt -lt 3 ]] || break
  sleep $((attempt * 2))
done
if [[ "$status" != "200" ]]; then
  echo "Error: MusicBrainz release lookup failed (HTTP $status)" >&2
  exit 3
fi

if [[ -n "$TITLES_FROM" && ! -f "$TITLES_FROM" ]]; then
  echo "Error: file not found: $TITLES_FROM" >&2
  exit 1
fi

python3 -I - "$TMP" "$GENRE" "$ALBUM" "$ALBUM_ARTIST" "$COMPILATION" "$STRAIGHT" "$DISCIDS" \
  "$TITLES_FROM" <<'PY'
import json, sys

body, genre, album, album_artist, compilation, straight, discids, titles_from = sys.argv[1:9]
rel = json.load(open(body))
discids = json.loads(discids)
override = json.load(open(titles_from)) if titles_from else {}
QUOTES = str.maketrans({"’": "'", "‘": "'", "“": '"', "”": '"',
                        "′": "'", "″": '"',  # primes: 12″, 7′
                        "‐": "-", "‑": "-", "–": "-", "—": "-"})


def text(s):
    return s.translate(QUOTES) if straight == "true" and s else s


def credit(credits):
    return "".join(c.get("name", "") + c.get("joinphrase", "") for c in credits or [])


artist = credit(rel.get("artist-credit"))
audio = [m for m in rel.get("media", []) if "CD" in (m.get("format") or "CD")]
label = (rel.get("label-info") or [{}])[0]
date = rel.get("date") or ""
discs = []
for i, m in enumerate(audio):
    n = str(i + 1)
    titles = override.get(n)
    if titles is not None and len(titles) != len(m.get("tracks", [])):
        print("Error: --titles-from has %d titles for disc %s, MusicBrainz has %d tracks"
              % (len(titles), n, len(m.get("tracks", []))), file=sys.stderr)
        sys.exit(1)
    discs.append({
        "disc": i + 1,
        "medium": m.get("position"),
        "mb_discid": discids.get(n),
        "known_discids": [d["id"] for d in m.get("discs", [])],
        "accuraterip": None,
        "tracks": [{
            "n": t.get("position"),
            "title": text(titles[j] if titles else t.get("title")),
            "artist": text(credit(t.get("artist-credit")) or artist),
            "seconds": round(t["length"] / 1000, 1) if t.get("length") else None,
        } for j, t in enumerate(m.get("tracks", []))],
    })

json.dump({
    "mb_release_id": rel["id"],
    "album": text(album or rel.get("title")),
    "album_artist": text(album_artist or ("Various Artists" if compilation == "true" else artist)),
    "artist": text(artist),
    "year": date[:4] or None,
    "genre": genre,
    "compilation": compilation == "true",
    "disc_total": len(discs),
    "label": (label.get("label") or {}).get("name"),
    "catalog_number": label.get("catalog-number"),
    "cover_art": bool((rel.get("cover-art-archive") or {}).get("front")),
    "discs": discs,
}, sys.stdout, indent=2, ensure_ascii=False)
print()
PY
