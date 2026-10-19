"""The audio CD the media-management eval sandboxes and tests put in the drive.

One invented release, Night Drive - Afterglow Live: a box set of one DVD and
two CDs, with the two CDs also sold on their own as a 2-CD edition, so the
same disc belongs to two MusicBrainz releases (the box numbers its CDs as
media 2 and 3). Everything about it comes from here, so the stubs agree with
each other: the table of contents, the audio each track rips to (exact, so
AccurateRip checksums are stable), and the MusicBrainz, AccurateRip and Cover
Art Archive responses.

    cd-fixture.py toc <disc>                    cd-paranoia -Q output (stderr)
    cd-fixture.py audio <disc> <track> <out.wav> [--offset N]
    cd-fixture.py web <dir> <skill_lib_dir>     every web response, into dir
                                                (disc lookups, releases, a search)
    cd-fixture.py ids <skill_lib_dir>           disc IDs, as JSON

Exit codes: 0 success, 1 bad args.
"""

import json
import math
import os
import struct
import sys

ARTIST = "Night Drive"
ALBUM = "Afterglow Live"
BOX_ID = "5e1d1c3a-7a10-4b2e-9c55-0b1d2e3f4a01"
CD2_ID = "5e1d1c3a-7a10-4b2e-9c55-0b1d2e3f4a02"
DRIVE_OFFSET = 6  # the read offset the stub drive needs; config sets it

# Titles as MusicBrainz has them, and lengths in seconds.
DISCS = {
    1: [("Dusk", 7), ("Neon Rain", 6), ("Overpass (Hall Mix)", 8)],
    2: [("Last Train", 6), ("Undertow", 7), ("Glasshouse ‐ Reprise", 5)],
}
# The suffix Apple Music's own CD lookup adds to every title.
LIVE_SUFFIX = " (Live at Hall 7, Berlin 14.03.26)"


def toc(disc):
    offsets, pos = [], 0
    for _, secs in DISCS[disc]:
        offsets.append(pos)
        pos += secs * 75
    return {"first": 1, "last": len(offsets), "offsets": offsets, "leadout": pos}


def samples(disc, track, offset=DRIVE_OFFSET):
    """Track audio as 16-bit stereo frames. A drive read with the wrong
    offset starts a few samples early or late, as on a real drive."""
    secs = DISCS[disc][track - 1][1]
    n = secs * 75 * 588
    shift = DRIVE_OFFSET - offset
    hz = 220 + 110 * track + 330 * disc
    out = bytearray()
    for i in range(n):
        t = i - shift
        left = int(9000 * math.sin(2 * math.pi * hz * t / 44100)) if t >= 0 else 0
        right = int(7000 * math.sin(2 * math.pi * (hz * 1.5) * t / 44100)) if t >= 0 else 0
        out += struct.pack("<hh", left, right)
    return bytes(out)


def write_wav(path, pcm):
    header = b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVE"
    header += b"fmt " + struct.pack("<IHHIIHH", 16, 1, 2, 44100, 44100 * 4, 4, 16)
    header += b"data" + struct.pack("<I", len(pcm))
    with open(path, "wb") as f:
        f.write(header + pcm)


def paranoia_toc(disc):
    t = toc(disc)
    lines = ["cdparanoia III release 10.2 (stub)", "", "Table of contents (audio tracks only):",
             "track        length               begin        copy pre ch",
             "==========================================================="]
    bounds = t["offsets"] + [t["leadout"]]
    for i, start in enumerate(t["offsets"]):
        length = bounds[i + 1] - start
        lines.append("  %d.    %6d [%02d:%02d.%02d]    %6d [%02d:%02d.%02d]    OK   no  2" % (
            i + 1, length, length // 4500, length // 75 % 60, length % 75,
            start, start // 4500, start // 75 % 60, start % 75))
    lines.append("TOTAL  %6d [%02d:%02d.%02d]    (audio only)" % (
        t["leadout"], t["leadout"] // 4500, t["leadout"] // 75 % 60, t["leadout"] % 75))
    return "\n".join(lines) + "\n"


def credit(name):
    return [{"name": name, "joinphrase": ""}]


def medium(position, disc, discid):
    return {"position": position, "format": "CD", "title": "",
            "discs": [{"id": discid}],
            "tracks": [{"position": i + 1, "title": title, "length": secs * 1000,
                        "artist-credit": credit(ARTIST)}
                       for i, (title, secs) in enumerate(DISCS[disc])]}


def releases(ids):
    box = {"id": BOX_ID, "title": ALBUM, "date": "2026-03-14", "country": "XE",
           "barcode": "5000000000011", "artist-credit": credit(ARTIST),
           "label-info": [{"catalog-number": "TIDAL011BOX", "label": {"name": "Tidal Records"}}],
           "release-group": {"primary-type": "Album"}, "cover-art-archive": {"front": True},
           "media": [{"position": 1, "format": "DVD-Video", "title": "", "discs": [],
                      "tracks": [{"position": 1, "title": "Afterglow Live (film)", "length": 5400000,
                                  "artist-credit": credit(ARTIST)}]},
                     medium(2, 1, ids[1]), medium(3, 2, ids[2])]}
    cd2 = {"id": CD2_ID, "title": ALBUM, "date": "2026-03-14", "country": "GB",
           "barcode": "5000000000028", "artist-credit": credit(ARTIST),
           "label-info": [{"catalog-number": "TIDAL011CD", "label": {"name": "Tidal Records"}}],
           "release-group": {"primary-type": "Album"}, "cover-art-archive": {"front": True},
           "media": [medium(1, 1, ids[1]), medium(2, 2, ids[2])]}
    return box, cd2


def accuraterip_dbar(disc, lib):
    sys.path.insert(0, lib)
    import accuraterip as ar
    import array
    tracks = []
    count = len(DISCS[disc])
    for n in range(1, count + 1):
        frames = array.array("I")
        frames.frombytes(samples(disc, n))
        _, v2 = ar.checksums(frames, n == 1, n == count)
        tracks.append(v2)
    ids = __import__("disc").accuraterip_ids(toc(disc))
    out = struct.pack("<BIII", count, int(ids["id1"], 16), int(ids["id2"], 16), int(ids["cddb"], 16))
    for crc in tracks:
        out += struct.pack("<BII", 18, crc, 0)
    return ids["url"], out


def disc_ids(lib):
    sys.path.insert(0, lib)
    import disc as d
    return {n: d.musicbrainz_discid(toc(n)) for n in DISCS}


def main(argv):
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 1
    cmd = argv[1]
    if cmd == "toc":
        sys.stderr.write(paranoia_toc(int(argv[2])))
    elif cmd == "audio":
        offset = int(argv[6]) if len(argv) > 6 and argv[5] == "--offset" else DRIVE_OFFSET
        write_wav(argv[4], samples(int(argv[2]), int(argv[3]), offset))
    elif cmd == "ids":
        print(json.dumps(disc_ids(argv[2])))
    elif cmd == "web":
        out, lib = argv[2], argv[3]
        os.makedirs(out, exist_ok=True)
        ids = disc_ids(lib)
        box, cd2 = releases(ids)
        for n, discid in ids.items():
            with open(os.path.join(out, "mb-discid-%s.json" % discid), "w") as f:
                json.dump({"id": discid, "releases": [box, cd2]}, f)
            url, data = accuraterip_dbar(n, lib)
            with open(os.path.join(out, os.path.basename(url)), "wb") as f:
                f.write(data)
        for rel in (box, cd2):
            with open(os.path.join(out, "mb-release-%s.json" % rel["id"]), "w") as f:
                json.dump(rel, f)
        # A search (artist + album) finds both editions.
        with open(os.path.join(out, "mb-search.json"), "w") as f:
            json.dump({"count": 2, "releases": [dict(r, score=100) for r in (box, cd2)]}, f)
    else:
        print("Error: unknown command %s" % cmd, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
