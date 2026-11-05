"""The track library behind the eval sandboxes' Apple Music stub.

Plays the parts of Apple Music the plugin's AppleScripts use, on real files:
it imports MP3s from the auto-import folder into the library folder, filed
and named the way Apple Music does ("Artist/Album/1-01 Title.mp3", with
characters it cannot use in names written as "_"); lists tracks; sets tags
(writing them into the file, artwork included, and moving the file when the
album or title changes); and deletes tracks. State: .eval/music/tracks.json.

    music-model.py <state_dir> ingest
    music-model.py <state_dir> list <artist> [album ...]
    music-model.py <state_dir> retag <values.tsv> [cover.jpg]
    music-model.py <state_dir> remove <ids.txt> look|delete

Paths come from <state_dir>/library.env (library_import, library_storage).
Exit codes: 0 success, 1 bad args.
"""

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys


def env(state):
    out = {}
    for line in open(os.path.join(state, "library.env")):
        if "=" in line:
            k, v = line.rstrip("\n").split("=", 1)
            out[k] = v.strip("'")
    return out


def load(state):
    path = os.path.join(state, "tracks.json")
    return json.load(open(path)) if os.path.exists(path) else []


def save(state, tracks):
    with open(os.path.join(state, "tracks.json"), "w") as f:
        json.dump(tracks, f, indent=1, ensure_ascii=False)


def safe(name):
    return re.sub(r'[/:"*?<>|]', "_", name)


def probe(path):
    out = subprocess.run(["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format",
                          "-show_streams", path], capture_output=True, text=True).stdout
    return json.loads(out or "{}")


def num(value, index=0):
    try:
        return int(str(value or "0").split("/")[index])
    except (ValueError, IndexError):
        return 0


def filed_path(storage, t):
    folder = os.path.join(storage, safe(t["album_artist"] or t["artist"]), safe(t["album"]))
    if t["disc_count"] > 1:
        name = "%d-%02d %s.mp3" % (t["disc"], t["track"], safe(t["name"]))
    else:
        name = "%02d %s.mp3" % (t["track"], safe(t["name"]))
    return os.path.join(folder, name)


def move(t, storage):
    new = filed_path(storage, t)
    if new != t["location"]:
        os.makedirs(os.path.dirname(new), exist_ok=True)
        shutil.move(t["location"], new)
        # Tidy the album and artist folders a move empties, as Apple Music
        # does; never the import folder or the library folder itself.
        old_dir = os.path.dirname(t["location"])
        for _ in range(2):
            if (old_dir.startswith(storage.rstrip("/") + "/") and os.path.isdir(old_dir)
                    and not os.listdir(old_dir)):
                os.rmdir(old_dir)
                old_dir = os.path.dirname(old_dir)
        t["location"] = new


def ingest(state):
    cfg = env(state)
    imp, storage = cfg.get("library_import"), cfg.get("library_storage")
    tracks = load(state)
    if not imp or not os.path.isdir(imp):
        return tracks
    for f in sorted(os.listdir(imp)):
        src = os.path.join(imp, f)
        if not f.lower().endswith(".mp3") or not os.path.isfile(src):
            continue
        p = probe(src)
        tags = {k.lower(): v for k, v in (p.get("format", {}).get("tags") or {}).items()}
        fmt = p.get("format", {})
        t = {
            "name": tags.get("title") or os.path.splitext(f)[0],
            "artist": tags.get("artist", ""), "album_artist": tags.get("album_artist", ""),
            "album": tags.get("album", ""),
            "disc": num(tags.get("disc")), "disc_count": num(tags.get("disc"), 1),
            "track": num(tags.get("track")), "track_count": num(tags.get("track"), 1),
            "compilation": tags.get("compilation") in ("1", "true"),
            "kind": "MPEG audio file", "bit_rate": round(int(fmt.get("bit_rate", "0")) / 1000),
            "year": num(tags.get("date")), "genre": tags.get("genre", ""),
            "duration": round(float(fmt.get("duration", "0")), 1),
            "location": src,
        }
        t["id"] = hashlib.sha1(("%s|%d" % (src, len(tracks))).encode()).hexdigest()[:16].upper()
        move(t, storage)
        tracks.append(t)
    save(state, tracks)
    return tracks


def list_tracks(state, artist, albums):
    for t in ingest(state):
        if artist.lower() not in t["artist"].lower() and artist.lower() not in t["album_artist"].lower():
            continue
        if albums and t["album"] not in albums:
            continue
        print("\t".join(str(x) for x in [
            t["id"], t["name"], t["artist"], t["album_artist"], t["album"], t["disc"],
            t["disc_count"], t["track"], t["track_count"], "true" if t["compilation"] else "false",
            t["kind"], t["bit_rate"], t["year"], t["genre"], t["duration"], t["location"]]))


def write_tags(t, cover, art):
    tmp = t["location"] + ".stub.mp3"
    cmd = ["ffmpeg", "-v", "error", "-y", "-i", t["location"]]
    if art == "set" and cover:
        cmd += ["-i", cover, "-map", "0:a", "-map", "1:v", "-c:v", "copy",
                "-disposition:v", "attached_pic"]
    elif art == "delete":
        cmd += ["-map", "0:a"]
    else:
        cmd += ["-map", "0"]
    cmd += ["-c:a", "copy", "-map_metadata", "0", "-id3v2_version", "3"]
    for key, value in (("title", t["name"]), ("artist", t["artist"]), ("album", t["album"]),
                       ("album_artist", t["album_artist"]),
                       ("disc", "%d/%d" % (t["disc"], t["disc_count"])),
                       ("track", "%d/%d" % (t["track"], t["track_count"])),
                       ("date", str(t["year"] or "")), ("genre", t["genre"]),
                       ("compilation", "1" if t["compilation"] else "")):
        cmd += ["-metadata", "%s=%s" % (key, value)]
    subprocess.run(cmd + [tmp], check=True)
    os.replace(tmp, t["location"])


def retag(state, values, cover):
    storage = env(state)["library_storage"]
    tracks = ingest(state)
    by_id = {t["id"]: t for t in tracks}
    for line in open(values, encoding="utf-8"):
        v = line.rstrip("\n").split("\t")
        if len(v) < 13:
            continue
        t = by_id.get(v[0])
        if not t:
            print("%s\tERROR Can't get track" % v[0])
            continue
        t.update({"name": v[1], "artist": v[2], "album": v[3], "album_artist": v[4],
                  "disc": int(v[5]), "disc_count": int(v[6]), "track": int(v[7]),
                  "track_count": int(v[8]), "year": int(v[9]), "genre": v[10],
                  "compilation": v[11] == "true"})
        write_tags(t, cover, v[12])
        move(t, storage)
        print("%s\t%s" % (t["id"], t["location"]))
    save(state, tracks)


def remove(state, ids_file, mode):
    tracks = ingest(state)
    wanted = [l.strip() for l in open(ids_file) if l.strip()]
    keep = []
    for t in tracks:
        if t["id"] in wanted and mode == "delete":
            continue
        keep.append(t)
    for pid in wanted:
        t = next((x for x in tracks if x["id"] == pid), None)
        print("%s\t%s\t%s" % (pid, "yes" if t else "no", t["location"] if t else ""))
    if mode == "delete":
        save(state, keep)


def main(argv):
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 1
    state, cmd = argv[1], argv[2]
    if cmd == "ingest":
        ingest(state)
    elif cmd == "list":
        list_tracks(state, argv[3], [a for a in argv[4:] if a])
    elif cmd == "retag":
        retag(state, argv[3], argv[4] if len(argv) > 4 and argv[4] else None)
    elif cmd == "remove":
        remove(state, argv[3], argv[4])
    else:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
