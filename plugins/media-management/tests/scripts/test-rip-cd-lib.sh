#!/usr/bin/env bash
# rip-cd's disc and AccurateRip libraries, against ground truth: the table of
# contents of a real disc (Depeche Mode: M, disc 3 of the box set) whose
# MusicBrainz disc ID and AccurateRip entry were looked up live, and a slow
# by-the-book checksum the fast one must agree with.
set -euo pipefail

FIXTURES_DIR="${1:-tests/fixtures}"
PROJECT_ROOT="${2:-.}"
LIB="$PROJECT_ROOT/skills/rip-cd/scripts/lib"
FIXTURE="$PROJECT_ROOT/evals/files/cd-fixture.py"
TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT
: "$FIXTURES_DIR"

python3 -I - "$LIB" "$FIXTURE" "$TEST_TMPDIR" <<'PY'
import array, importlib.util, os, plistlib, struct, sys

lib, fixture_path, tmp = sys.argv[1:4]
sys.path.insert(0, lib)
import accuraterip as ar
import disc

spec = importlib.util.spec_from_file_location("cdfixture", fixture_path)
fx = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fx)

failures = []


def check(name, got, want):
    if got != want:
        failures.append("%s: got %r, want %r" % (name, got, want))


# --- Ground truth: a real disc --------------------------------------------
M = {"first": 1, "last": 14, "leadout": 315136,
     "offsets": [0, 10371, 32849, 48647, 79353, 101744, 127376, 150485, 181227,
                 203744, 224980, 251727, 274423, 292771]}
check("MusicBrainz disc ID (real disc)", disc.musicbrainz_discid(M), "goxMYo.uO4MZRDdtCiHWzwXW0ss-")
check("AccurateRip URL (real disc)", disc.accuraterip_ids(M)["url"],
      "http://www.accuraterip.com/accuraterip/1/3/4/dBAR-014-00230431-017d1273-a410690e.bin")
check("MusicBrainz TOC parameter", disc.musicbrainz_toc(M).split("+")[:4], ["1", "14", "315286", "150"])

# The plist macOS writes counts sectors from the pregap: same TOC either way.
plist = os.path.join(tmp, "TOC.plist")
with open(plist, "wb") as f:
    plistlib.dump({"Sessions": [{"First Track": 1, "Last Track": 14, "Leadout Block": M["leadout"] + 150,
                                 "Track Array": [{"Data": False, "Point": i + 1, "Start Block": o + 150}
                                                 for i, o in enumerate(M["offsets"])]}]}, f)
check(".TOC.plist reader", disc.toc_from_plist(plist), M)

# cd-paranoia -Q output (as the stub drive prints it, in the real format).
import io, contextlib
err = io.StringIO()
with contextlib.redirect_stderr(err):
    fx.main(["cd-fixture.py", "toc", "1"])
check("cd-paranoia -Q reader", disc.toc_from_paranoia(err.getvalue()), fx.toc(1))
check("track lengths", disc.track_lengths(fx.toc(1)), [525, 450, 600])

# --- Repeated suffixes: disc 2 of the real box, as Apple Music named it ----
live = " (Live At Foro Sol (Mexico City) 21/23/25.09.23)"
titles = ["A Pain That I'm Used To (Jacques Lu Cont Remix)" + live, "World In My Eyes" + live,
          "Wrong" + live, "Survive (Memento Mori Sessions)", "Life 2.0 (Memento Mori Sessions)"]
found = disc.repeated_suffixes(titles)
check("suffix groups", [(e["suffix"], e["tracks"]) for e in found],
      [(live.strip(), [1, 2, 3]), ("(Memento Mori Sessions)", [4, 5])])
check("strip only the release-wide suffix", disc.strip_suffixes(titles, {live.strip()})[:1] +
      disc.strip_suffixes(titles, {live.strip()})[3:4],
      ["A Pain That I'm Used To (Jacques Lu Cont Remix)", "Survive (Memento Mori Sessions)"])
check("nested brackets", disc.trailing_group("Intro (live at Foro Sol (Mexico City) 2023)"),
      " (live at Foro Sol (Mexico City) 2023)")
check("whole title bracketed is no suffix", disc.trailing_group("(Untitled)"), None)
check("no brackets", disc.trailing_group("Dusk"), None)


# --- AccurateRip checksums: fast == by the book -----------------------------
def reference(frames, first, last):
    """AccurateRip as specified, one sample at a time."""
    n = len(frames)
    v1 = v2 = 0
    for i in range(n):
        m = i + 1
        if first and m < ar.SKIP:
            continue
        if last and m > n - ar.SKIP:
            continue
        p = frames[i] * m
        v1 = (v1 + p) & 0xFFFFFFFF
        v2 = (v2 + (p & 0xFFFFFFFF) + (p >> 32)) & 0xFFFFFFFF
    return v1, v2


wav = os.path.join(tmp, "t.wav")
fx.write_wav(wav, fx.samples(1, 2))
frames = ar.read_wav_samples(wav)
check("sample count", len(frames), 6 * 75 * 588)
for first, last in ((True, False), (False, False), (False, True), (True, True)):
    check("checksums first=%s last=%s" % (first, last), ar.checksums(frames, first, last),
          reference(frames, first, last))

# A wrong read offset shifts the audio, so the checksum changes.
shifted = array.array("I")
shifted.frombytes(fx.samples(1, 2, offset=0))
if ar.checksums(shifted, False, False) == ar.checksums(frames, False, False):
    failures.append("a 6-sample offset error should change the checksum")

# dBAR: parse and match, including the best of several pressings.
v1, v2 = ar.checksums(frames, False, False)
dbar = struct.pack("<BIII", 2, 1, 2, 3) + struct.pack("<BII", 5, 0xDEAD, 0) + struct.pack("<BII", 7, v2, 0)
dbar += struct.pack("<BIII", 2, 1, 2, 3) + struct.pack("<BII", 2, 0, 0) + struct.pack("<BII", 30, v1, 0)
pressings = ar.parse_dbar(dbar)
check("dBAR pressings", len(pressings), 2)
check("best match", ar.match(v1, v2, 1, pressings), (30, "v1"))
check("no match", ar.match(1, 2, 0, pressings), None)

# Not CD audio is refused, not mis-checksummed.
mono = os.path.join(tmp, "mono.wav")
with open(mono, "wb") as f:
    f.write(b"RIFF" + struct.pack("<I", 36) + b"WAVE" + b"fmt " +
            struct.pack("<IHHIIHH", 16, 1, 1, 44100, 88200, 2, 16) + b"data" + struct.pack("<I", 0))
try:
    ar.read_wav_samples(mono)
    failures.append("a mono WAV should be refused")
except ValueError:
    pass

if failures:
    for f in failures:
        print("FAIL: " + f)
    sys.exit(1)
PY

echo "All rip-cd library tests passed"
