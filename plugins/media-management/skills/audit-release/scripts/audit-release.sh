#!/usr/bin/env bash
# Check one release against everything a finished import should be: one album
# in Apple Music, clean tags, MP3s and WAVs on the NAS, nothing left behind.
# Usage: audit-release.sh --artist NAME --album NAME [--album NAME ...] [--release FILE]
# Output: JSON to stdout
# Exit codes: 0=audited (whatever it found), 1=bad args, 2=file not found, 3=Apple Music error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

show_help() {
  cat <<'HELP'
Usage: audit-release.sh --artist NAME --album NAME [--album NAME ...] [--release FILE]

Read-only. Gathers a release's state from Apple Music, the library folder,
the NAS staging folder, Downloads and the auto-import folder, and checks it.
Name every album the release is currently split across ("M" and
"M [Disc 2]"); find-splits.sh finds them.

Checks:
  one_album         Apple Music shows a single album (one Album + Album Artist)
  album_artist      Album Artist is set, the same on every track
  disc_tags         Disc n/N and track n/N are set and agree across tracks
  complete          Every disc has as many tracks as its track count says
  clean_titles      No bracketed suffix repeated across tracks; with --release,
                    titles equal the release record's
  mp3_320           Every track is an MP3 at 320 kbps
  release_id        Every file carries the same MusicBrainz Album Id tag
  artwork           Every file has an embedded front cover
  files_present     Apple Music has a file for every track
  nas_mp3           The MP3s are staged on the NAS, same count
  nas_wav           The WAVs are staged on the NAS, same count, with release.json
  rip_verified      release.json says each disc's rip matched AccurateRip
  no_leftovers      Nothing for this release in Downloads or the auto-import folder

Arguments:
  --artist NAME   The release's artist
  --album NAME    An album name it appears under in Apple Music; repeatable
  --release FILE  The confirmed release record (rip-cd's release.json), to
                  check titles and the disc count against
  --out FILE      Also write the JSON output to FILE
  --help          Show this help

Output: JSON to stdout
  {
    "ok": false,
    "groups": [...], "track_count": 28,
    "checks": [{"id": "one_album", "ok": false,
                "detail": "2 albums: M — Depeche Mode (14), M [Disc 2] — Depeche Mode (14)"}, ...],
    "fixes": [{"fix": "retag", "for": ["one_album", "album_artist", "clean_titles"]}, ...],
    "paths": {"library_folders": [...], "nas_mp3": "...", "nas_wav": "..."}
  }
  fixes, in the order to run them: retag (repair-release.sh), rip_wav
  (rip-cd, WAVs only), archive_mp3 / archive_wav (archive-media),
  remove_leftovers (cleanup), replace (re-rip everything through rip-cd).

Exit codes:
  0  Audited, whatever it found
  1  Bad arguments
  2  --release file not found
  3  Apple Music could not be queried
HELP
}

# shellcheck source-path=SCRIPTDIR source=../../rip-cd/scripts/lib/out.sh
source "$SCRIPT_DIR/../../rip-cd/scripts/lib/out.sh"
with_out "${BASH_SOURCE[0]}" "$@"

ARTIST=""
ALBUM_ARGS=()
RELEASE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) show_help; exit 0 ;;
    --artist) ARTIST="${2:-}"; shift 2 ;;
    --album) ALBUM_ARGS+=(--album "${2:-}"); shift 2 ;;
    --release) RELEASE="${2:-}"; shift 2 ;;
    *) echo "Error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$ARTIST" || ${#ALBUM_ARGS[@]} -eq 0 ]]; then
  echo "Error: --artist and at least one --album required" >&2
  show_help >&2
  exit 1
fi
if [[ -n "$RELEASE" && ! -f "$RELEASE" ]]; then
  echo "Error: file not found: $RELEASE" >&2
  exit 2
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/audit-release.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

bash "$SCRIPT_DIR/music-tracks.sh" --artist "$ARTIST" "${ALBUM_ARGS[@]}" >"$TMP/tracks.json" || exit 3
bash "$PLUGIN_ROOT/skills/setup/scripts/check-config.sh" >"$TMP/config.json"

# From each file Apple Music has: its MusicBrainz Album Id tag, and whether a
# cover is embedded (a cover Apple Music found itself lives only in its cache).
jq -r '.tracks[] | select(.location) | [.id, .location] | @tsv' "$TMP/tracks.json" |
  while IFS=$'\t' read -r id loc; do
    probe=$(ffprobe -v quiet -show_format -show_streams -of json "$loc" 2>/dev/null || echo '{}')
    mbid=$(echo "$probe" |
      jq -r '.format.tags | to_entries[]? | select(.key | ascii_downcase == "musicbrainz album id") | .value' | head -1)
    art=$(echo "$probe" | jq -r 'if any(.streams[]?; .disposition.attached_pic == 1) then "yes" else "no" end')
    printf '%s\t%s\t%s\n' "$id" "$mbid" "$art"
  done >"$TMP/files.tsv"

python3 -I - "$PLUGIN_ROOT/skills/rip-cd/scripts/lib" "$TMP" "$RELEASE" <<'PY'
import glob, json, os, re, sys
sys.path.insert(0, sys.argv[1])
import disc as discmod

tmp, release_path = sys.argv[2], sys.argv[3]
data = json.load(open(os.path.join(tmp, "tracks.json")))
config = {i["key"]: i["value"] for i in json.load(open(os.path.join(tmp, "config.json")))["items"]}
files = {}
for line in open(os.path.join(tmp, "files.tsv")):
    parts = line.rstrip("\n").split("\t")
    if len(parts) == 3:
        files[parts[0]] = {"mbid": parts[1], "art": parts[2] == "yes"}
mbids = {k: v["mbid"] for k, v in files.items()}
release = json.load(open(release_path)) if release_path else None
tracks, groups = data["tracks"], data["groups"]
checks = []


def check(cid, ok, detail):
    checks.append({"id": cid, "ok": bool(ok), "detail": detail})


if not tracks:
    print(json.dumps({"ok": False, "groups": [], "track_count": 0, "checks": [
        {"id": "found", "ok": False, "detail": "no tracks for these albums in Apple Music"}],
        "fixes": [{"fix": "replace", "for": ["found"]}], "paths": {}}, indent=2))
    sys.exit(0)

check("one_album", len(groups) == 1,
      "1 album: %s" % groups[0]["shown_as"] if len(groups) == 1 else
      "%d albums: %s" % (len(groups), ", ".join("%s (%d)" % (g["shown_as"], g["tracks"]) for g in groups)))

aas = sorted({t["album_artist"] for t in tracks})
check("album_artist", aas != [""] and len(aas) == 1,
      "Album Artist %r on every track" % aas[0] if len(aas) == 1 and aas[0] else
      "Album Artist: %s" % ", ".join(repr(a) for a in aas))

disc_counts = sorted({t["disc_count"] for t in tracks})
discs = sorted({t["disc"] for t in tracks})
want_discs = release["disc_total"] if release else (disc_counts[0] if len(disc_counts) == 1 else None)
problems = []
if len(disc_counts) != 1 or disc_counts[0] < 1:
    problems.append("disc totals %s" % disc_counts)
if any(d < 1 or (want_discs and d > want_discs) for d in discs):
    problems.append("disc numbers %s outside 1..%s" % (discs, want_discs))
by_disc = {}
for t in tracks:
    by_disc.setdefault(t["disc"], []).append(t)
for d, ts in sorted(by_disc.items()):
    counts = {t["track_count"] for t in ts}
    if len(counts) != 1 or 0 in counts:
        problems.append("disc %d track totals %s" % (d, sorted(counts)))
check("disc_tags", not problems, "; ".join(problems) or
      "%d disc(s), disc and track totals consistent" % len(discs))

missing = []
if want_discs:
    absent = [d for d in range(1, want_discs + 1) if d not in by_disc]
    if absent:
        missing.append("disc%s %s of %d not imported yet" % (
            "s" if len(absent) > 1 else "", ", ".join(map(str, absent)), want_discs))
for d, ts in sorted(by_disc.items()):
    expected = ts[0]["track_count"]
    if release:
        rd = [x for x in release["discs"] if x["disc"] == d]
        expected = len(rd[0]["tracks"]) if rd else expected
    have = sorted(t["track"] for t in ts)
    if have != list(range(1, expected + 1)):
        missing.append("disc %d has tracks %s of %d" % (d, have, expected))
check("complete", not missing, "; ".join(missing) or "every disc complete")

if release:
    want = {(d["disc"], t["n"]): t["title"] for d in release["discs"] for t in d["tracks"]}
    wrong = [t for t in tracks if want.get((t["disc"], t["track"])) not in (None, t["name"])]
    check("clean_titles", not wrong,
          "%d titles differ from the release record, e.g. %r -> %r" % (
              len(wrong), wrong[0]["name"], want[(wrong[0]["disc"], wrong[0]["track"])])
          if wrong else "titles match the release record")
else:
    repeated = discmod.repeated_suffixes([t["name"] for t in tracks])
    check("clean_titles", not repeated,
          "; ".join("%r on %d tracks" % (r["suffix"], r["count"]) for r in repeated)
          or "no repeated suffixes")

bad_format = [t for t in tracks if "MPEG" not in t["kind"] or t["bit_rate"] < 320]
check("mp3_320", not bad_format,
      "%d tracks not MP3 320, e.g. %s at %dk" % (len(bad_format), bad_format[0]["kind"], bad_format[0]["bit_rate"])
      if bad_format else "all MP3 320")

ids = {mbids.get(t["id"], "") for t in tracks if t["location"]}
check("release_id", len(ids) == 1 and "" not in ids,
      "MusicBrainz Album Id %s" % next(iter(ids)) if len(ids) == 1 and "" not in ids else
      "no MusicBrainz Album Id tag" if ids == {""} else "Album Ids differ: %s" % sorted(ids))

no_art = [t for t in tracks if t["location"] and not files.get(t["id"], {}).get("art")]
check("artwork", not no_art,
      "%d of %d files have no embedded cover (Apple Music may be showing a guess)" % (len(no_art), len(tracks))
      if no_art else "every file has an embedded cover")

no_file = [t for t in tracks if not t["location"]]
check("files_present", not no_file, "%d tracks have no file" % len(no_file) if no_file else "every track has its file")

# Where Apple Music actually filed them (its folder names replace ":" with "_").
folders = sorted({os.path.dirname(t["location"]) for t in tracks if t["location"]})
nas = config.get("archive_workdir")
paths = {"library_folders": folders, "nas_mp3": None, "nas_wav": None}
if nas and len(folders) == 1:
    artist_dir, album_dir = folders[0].rstrip("/").split("/")[-2:]
    paths["nas_mp3"] = os.path.join(nas, "to_nas", "mp3", artist_dir, album_dir)
    paths["nas_wav"] = os.path.join(nas, "to_nas", "wav", artist_dir, album_dir)
elif nas:
    # Split across folders: look under every one of them.
    paths["nas_mp3"] = [os.path.join(nas, "to_nas", "mp3", *f.rstrip("/").split("/")[-2:]) for f in folders]
    paths["nas_wav"] = [os.path.join(nas, "to_nas", "wav", *f.rstrip("/").split("/")[-2:]) for f in folders]


def count(dirs, ext):
    dirs = dirs if isinstance(dirs, list) else [dirs] if dirs else []
    return sum(len(glob.glob(os.path.join(glob.escape(d), "*." + ext))) for d in dirs)


n = len(tracks)
mp3s = count(paths["nas_mp3"], "mp3")
check("nas_mp3", mp3s == n, "%d of %d MP3s on the NAS" % (mp3s, n))
wavs = count(paths["nas_wav"], "wav")
wav_dirs = paths["nas_wav"] if isinstance(paths["nas_wav"], list) else [paths["nas_wav"]] if paths["nas_wav"] else []
records = [os.path.join(d, "release.json") for d in wav_dirs if os.path.isfile(os.path.join(d, "release.json"))]
check("nas_wav", wavs == n and records,
      "%d of %d WAVs on the NAS%s" % (wavs, n, "" if records else ", no release.json"))

verified = []
if records:
    rec = json.load(open(records[0]))
    # Only the discs imported so far: discs not ripped yet are complete's to report.
    verified = [d.get("accuraterip") for d in rec.get("discs", []) if d.get("disc") in by_disc]
check("rip_verified", verified and all(v in ("verified", "not_in_database") for v in verified),
      "AccurateRip per disc: %s" % verified if verified else "no record of a verified rip")

album_names = {t["album"] for t in tracks}
# Folders, ZIPs and audio files whose name holds the album name as a whole
# word: an album called "M" must not claim "Message.pdf".
LEFTOVER_EXT = (".zip", ".mp3", ".wav", ".aiff", ".flac", ".m4a")
leftovers = []
for key in ("downloads", "library_import"):
    base = config.get(key)
    if not base or not os.path.isdir(base):
        continue
    for entry in sorted(os.listdir(base)):
        full = os.path.join(base, entry)
        if not (os.path.isdir(full) or entry.lower().endswith(LEFTOVER_EXT)):
            continue
        stem = os.path.splitext(entry)[0] if os.path.isfile(full) else entry
        for name in album_names:
            word = re.escape(name.replace(":", "_").replace("/", "_"))
            if re.search(r"(^|[\s\-_(\[])%s($|[\s\-_)\].])" % word, stem, re.I):
                leftovers.append(full)
                break
check("no_leftovers", not leftovers, "leftovers: %s" % leftovers if leftovers else "nothing left behind")

failed = {c["id"] for c in checks if not c["ok"]}
fixes = []


def want_fix(fix, ids):
    hit = [i for i in ids if i in failed]
    if hit:
        fixes.append({"fix": fix, "for": hit})


if {"mp3_320", "files_present"} & failed:
    want_fix("replace", ["mp3_320", "files_present", "rip_verified"])
else:
    want_fix("retag", ["one_album", "album_artist", "disc_tags", "clean_titles", "release_id", "artwork"])
    want_fix("rip_wav", ["rip_verified"] if "nas_wav" not in failed else ["nas_wav", "rip_verified"])
    want_fix("archive_mp3", ["nas_mp3"])
want_fix("remove_leftovers", ["no_leftovers"])
if "complete" in failed:
    fixes.append({"fix": "rip_missing_tracks", "for": ["complete"]})

print(json.dumps({"ok": not failed, "groups": groups, "track_count": n, "checks": checks,
                  "fixes": fixes, "paths": paths}, indent=2, ensure_ascii=False))
PY
