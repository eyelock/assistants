#!/usr/bin/env bash
# Find releases Apple Music shows as more than one album, for one artist.
# Usage: find-splits.sh --artist NAME [--deep]
# Output: JSON to stdout
# Exit codes: 0=success (none found is not an error), 1=bad args, 3=Apple Music error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
  cat <<'HELP'
Usage: find-splits.sh --artist NAME [--deep]

Read-only. Group an artist's albums in Apple Music into likely splits: one
release shown as several albums. Apple Music shows one album per distinct
Album + Album Artist, so a split is two or more of those pairs that are
really the same release:

  disc_suffix     names equal once a disc marker is removed:
                  "M" and "M [Disc 2]", "Retro (CD1)", "Album - Disc 2"
  name_variant    names equal ignoring case, curly quotes and spacing:
                  "Waiting For the Sirens' Call" and "Waiting for the Sirens' Call"
  album_artist    the same album name under different Album Artists,
                  e.g. blank on one disc and set on another
  release_id      (--deep) files with the same MusicBrainz Album Id under
                  different albums. Reads every file's tags, so it is slower

Each split names the albums to pass to audit-release.sh --album.

Arguments:
  --artist NAME   Artist to check (substring match, as music-tracks.sh)
  --deep          Also compare MusicBrainz Album Id tags
  --out FILE      Also write the JSON output to FILE
  --help          Show this help

Output: JSON to stdout
  {
    "artist": "New Order", "albums": 27,
    "splits": [{"reason": "name_variant",
                "albums": [{"album": "Waiting For the Sirens' Call", "album_artist": "New Order", "tracks": 6},
                           {"album": "Waiting for the Sirens' Call", "album_artist": "", "tracks": 8}],
                "audit_args": ["--album", "Waiting For the Sirens' Call", "--album", "Waiting for the Sirens' Call"]}]
  }

Exit codes:
  0  Success, including no splits
  1  Bad arguments
  3  Apple Music could not be queried
HELP
}

# shellcheck source-path=SCRIPTDIR source=../../rip-cd/scripts/lib/out.sh
source "$SCRIPT_DIR/../../rip-cd/scripts/lib/out.sh"
with_out "${BASH_SOURCE[0]}" "$@"

ARTIST=""
DEEP=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) show_help; exit 0 ;;
    --artist) ARTIST="${2:-}"; shift 2 ;;
    --deep) DEEP=true; shift ;;
    *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done
if [[ -z "$ARTIST" ]]; then
  echo "Error: --artist required" >&2
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/find-splits.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

bash "$SCRIPT_DIR/music-tracks.sh" --artist "$ARTIST" >"$TMP/tracks.json" || exit 3

: >"$TMP/ids.tsv"
if [[ "$DEEP" == true ]]; then
  jq -r '.tracks[] | select(.location) | [.id, .location] | @tsv' "$TMP/tracks.json" |
    while IFS=$'\t' read -r id loc; do
      mbid=$(ffprobe -v quiet -show_format -of json "$loc" 2>/dev/null |
        jq -r '.format.tags | to_entries[]? | select(.key | ascii_downcase == "musicbrainz album id") | .value' | head -1)
      [[ -n "$mbid" ]] && printf '%s\t%s\n' "$id" "$mbid"
    done >"$TMP/ids.tsv"
fi

python3 -I - "$TMP/tracks.json" "$TMP/ids.tsv" <<'PY'
import json, re, sys

data = json.load(open(sys.argv[1]))
ids = dict(l.rstrip("\n").split("\t", 1) for l in open(sys.argv[2]) if "\t" in l)

# One entry per album Apple Music shows (Album + Album Artist).
albums = {}
for t in data["tracks"]:
    key = (t["album"], t["album_artist"])
    a = albums.setdefault(key, {"album": t["album"], "album_artist": t["album_artist"],
                                "tracks": 0, "release_ids": set()})
    a["tracks"] += 1
    if t["id"] in ids:
        a["release_ids"].add(ids[t["id"]])

DISC = re.compile(r"""\s*(?:[\[(]\s*(?:disc|disk|cd)\s*\d+\s*[\])]
                      |[-–:]\s*(?:disc|disk|cd)\s*\d+
                      |\s(?:disc|disk|cd)\s*\d+)\s*$""", re.I | re.X)
QUOTES = str.maketrans({"’": "'", "‘": "'", "“": '"', "”": '"',
                        "‐": "-", "–": "-", "—": "-"})


def variant(name):
    return re.sub(r"\s+", " ", name.translate(QUOTES)).strip().lower()


def base(name):
    return variant(DISC.sub("", name))


splits, used = [], set()


def add(reason, keys):
    keys = sorted(set(keys))
    if len(keys) < 2 or frozenset(keys) in used:
        return
    used.add(frozenset(keys))
    group = [dict(albums[k], release_ids=sorted(albums[k]["release_ids"])) for k in keys]
    args = []
    for name in sorted({k[0] for k in keys}):
        args += ["--album", name]
    splits.append({"reason": reason, "albums": group, "audit_args": args})


def group_by(fn):
    out = {}
    for k in albums:
        out.setdefault(fn(k), []).append(k)
    return [ks for ks in out.values() if len(ks) > 1]


for ks in group_by(lambda k: base(k[0])):
    names = {k[0] for k in ks}
    if any(DISC.search(n) for n in names):
        add("disc_suffix", ks)
for ks in group_by(lambda k: variant(k[0])):
    if len({k[0] for k in ks}) > 1:
        add("name_variant", ks)
for ks in group_by(lambda k: k[0]):
    add("album_artist", ks)
by_id = {}
for k, a in albums.items():
    for rid in a["release_ids"]:
        by_id.setdefault(rid, []).append(k)
for ks in by_id.values():
    add("release_id", ks)

json.dump({"artist": data["artist"], "albums": len(albums), "splits": splits},
          sys.stdout, indent=2, ensure_ascii=False)
print()
PY
