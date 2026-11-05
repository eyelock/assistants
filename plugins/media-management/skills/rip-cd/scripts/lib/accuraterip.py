"""AccurateRip v1/v2 checksums and the dBAR response format.

A rip matches when its checksum equals one some other ripper submitted for
the same disc; the confidence is how many rips agreed. Checksums assume an
offset-corrected rip, which cd-paranoia gives with -O <drive read offset>.
"""

import array
import itertools
import operator
import struct
import sys

SKIP = 5 * 588  # samples ignored at the very start and end of a disc
MASK = 0xFFFFFFFF


def read_wav_samples(path):
    """16-bit stereo PCM as one uint32 per sample (left in the low half)."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError("%s: not a WAV file" % path)
    pos = 12
    while pos + 8 <= len(data):
        cid, size = struct.unpack("<4sI", data[pos:pos + 8])
        if cid == b"fmt ":
            fmt, channels, rate, _, _, bits = struct.unpack("<HHIIHH", data[pos + 8:pos + 24])
            if (fmt, channels, rate, bits) != (1, 2, 44100, 16):
                raise ValueError("%s: not CD audio (44.1kHz 16-bit stereo PCM)" % path)
        if cid == b"data":
            pcm = data[pos + 8:pos + 8 + size]
            pcm = pcm[:len(pcm) - len(pcm) % 4]
            samples = array.array("I")
            samples.frombytes(pcm)
            if sys.byteorder != "little":
                samples.byteswap()
            return samples
        pos += 8 + size + (size & 1)
    raise ValueError("%s: no data chunk" % path)


def checksums(samples, first, last):
    """(v1, v2) for one track. first/last say whether it opens or closes the disc."""
    n = len(samples)
    start = SKIP if first else 1
    end = n - SKIP if last else n
    if end < start:
        return 0, 0
    weights = range(start, end + 1)
    window = itertools.islice(samples, start - 1, end)
    products = list(map(operator.mul, window, weights))
    v1 = sum(products) & MASK
    v2 = (sum(map(operator.and_, products, itertools.repeat(MASK)))
          + sum(map(operator.rshift, products, itertools.repeat(32)))) & MASK
    return v1, v2


def parse_dbar(data):
    """Each pressing: [count, id1, id2, cddb] then [confidence, crc, crc450] per track."""
    pressings = []
    pos = 0
    while pos + 13 <= len(data):
        count = data[pos]
        pos += 13
        tracks = []
        for _ in range(count):
            confidence, crc, _ = struct.unpack("<BII", data[pos:pos + 9])
            pos += 9
            tracks.append((confidence, crc))
        pressings.append(tracks)
    return pressings


def match(v1, v2, track_index, pressings):
    """Best agreeing entry for one track: (confidence, 'v1'|'v2') or None."""
    best = None
    for tracks in pressings:
        if track_index >= len(tracks):
            continue
        confidence, crc = tracks[track_index]
        kind = "v2" if crc == v2 else "v1" if crc == v1 else None
        if kind and (best is None or confidence > best[0]):
            best = (confidence, kind)
    return best
