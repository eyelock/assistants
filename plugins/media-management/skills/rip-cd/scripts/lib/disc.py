"""Disc identifiers from an audio CD's table of contents.

A TOC here is the list of track start sectors (LBA, counted from 0, as
cd-paranoia prints them) plus the lead-out sector. The MusicBrainz and
AccurateRip IDs are both pure functions of it, so they are computed locally
and only the lookups touch the network.
"""

import base64
import hashlib
import plistlib
import re

PREGAP = 150  # sectors before LBA 0 on every audio CD


def toc_from_plist(path):
    """Read the TOC macOS writes as .TOC.plist on a mounted audio CD."""
    with open(path, "rb") as f:
        data = plistlib.load(f)
    session = data["Sessions"][0]
    audio = [t for t in session["Track Array"] if not t.get("Data")]
    # The plist counts sectors from the start of the pregap.
    offsets = [t["Start Block"] - PREGAP for t in audio]
    return {
        "first": audio[0]["Point"],
        "last": audio[-1]["Point"],
        "offsets": offsets,
        "leadout": session["Leadout Block"] - PREGAP,
    }


def toc_from_paranoia(text):
    """Parse `cd-paranoia -Q` output (it writes the table to stderr)."""
    offsets = []
    leadout = None
    first = None
    for line in text.splitlines():
        m = re.match(r"^\s+(\d+)\.\s+(\d+)\s+\[[^]]*\]\s+(\d+)\s", line)
        if m:
            if first is None:
                first = int(m.group(1))
            offsets.append(int(m.group(3)))
            continue
        m = re.match(r"^TOTAL\s+(\d+)", line)
        if m:
            leadout = offsets[0] + int(m.group(1)) if offsets else int(m.group(1))
    if not offsets or leadout is None:
        raise ValueError("no track table in cd-paranoia output")
    return {"first": first, "last": first + len(offsets) - 1,
            "offsets": offsets, "leadout": leadout}


def musicbrainz_discid(toc):
    """https://musicbrainz.org/doc/Disc_ID_Calculation"""
    s = "%02X%02X" % (toc["first"], toc["last"])
    s += "%08X" % (toc["leadout"] + PREGAP)
    sectors = [o + PREGAP for o in toc["offsets"]]
    s += "".join("%08X" % o for o in sectors)
    s += "%08X" % 0 * (99 - len(sectors))
    digest = hashlib.sha1(s.encode("ascii")).digest()
    return base64.b64encode(digest).decode("ascii").translate(
        str.maketrans("+/=", "._-"))


def musicbrainz_toc(toc):
    """The `toc` parameter MusicBrainz takes for a fuzzy lookup."""
    parts = [toc["first"], toc["last"], toc["leadout"] + PREGAP]
    parts += [o + PREGAP for o in toc["offsets"]]
    return "+".join(str(p) for p in parts)


def _digit_sum(n):
    return sum(int(c) for c in str(n))


def accuraterip_ids(toc):
    offsets, leadout = toc["offsets"], toc["leadout"]
    n = len(offsets)
    id1 = sum(offsets) + leadout
    id2 = sum(max(o, 1) * (i + 1) for i, o in enumerate(offsets)) + leadout * (n + 1)
    checksum = sum(_digit_sum((o + PREGAP) // 75) for o in offsets)
    seconds = leadout // 75 - offsets[0] // 75
    cddb = ((checksum % 255) << 24) | (seconds << 8) | n
    id1 &= 0xFFFFFFFF
    id2 &= 0xFFFFFFFF
    url = ("http://www.accuraterip.com/accuraterip/%x/%x/%x/dBAR-%03d-%08x-%08x-%08x.bin"
           % (id1 & 0xF, id1 >> 4 & 0xF, id1 >> 8 & 0xF, n, id1, id2, cddb))
    return {"id1": "%08x" % id1, "id2": "%08x" % id2, "cddb": "%08x" % cddb, "url": url}


def trailing_group(title):
    """The bracketed group a title ends with, e.g. " (live at X (City) 2023)"."""
    title = title.rstrip()
    if not title or title[-1] not in ")]":
        return None
    close = title[-1]
    opener = "(" if close == ")" else "["
    depth = 0
    for i in range(len(title) - 1, -1, -1):
        if title[i] == close:
            depth += 1
        elif title[i] == opener:
            depth -= 1
            if depth == 0:
                if i == 0:
                    return None  # the whole title is bracketed
                return title[i:] if title[i - 1] != " " else title[i - 1:]
    return None


def repeated_suffixes(titles):
    """Trailing groups shared by two or more tracks, most common first.

    Each entry says which tracks carry it, so a suffix that only some tracks
    share (disc 2 of a set mixing live tracks and studio sessions) is
    reported for those tracks alone.
    """
    seen = {}
    for i, title in enumerate(titles):
        group = trailing_group(title)
        if group:
            seen.setdefault(group.strip(), []).append(i + 1)
    out = [{"suffix": s, "tracks": t, "count": len(t)}
           for s, t in seen.items() if len(t) >= 2]
    return sorted(out, key=lambda e: -e["count"])


def strip_suffixes(titles, suffixes):
    out = []
    for title in titles:
        group = trailing_group(title)
        if group and group.strip() in suffixes:
            title = title[:len(title) - len(group)].rstrip()
        out.append(title)
    return out


def track_lengths(toc):
    """Sectors per track: 588 stereo samples, 1/75 s, each."""
    bounds = toc["offsets"] + [toc["leadout"]]
    return [bounds[i + 1] - bounds[i] for i in range(len(toc["offsets"]))]
