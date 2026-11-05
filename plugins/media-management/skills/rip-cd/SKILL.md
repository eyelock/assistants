---
name: rip-cd
description: >-
  Rip an audio CD in the optical drive into Apple Music and the NAS: identify
  it on MusicBrainz, ask the usual questions, securely rip and verify it
  against AccurateRip, then make tagged MP3 320s (to Apple Music) and WAVs
  (lossless backup) from the one verified rip. Use when the user has a CD in
  the drive ("rip this CD", "import the disc", "I've put disc 2 in"), even
  if they don't say "rip", and to carry on with a disc already ripped ("disc
  1 looks right in Apple Music, put it on the NAS"). Not for downloaded
  purchases (process-album) or for fixing an album already in Apple Music
  (audit-release).
allowed-tools: Bash Read Write Skill
---

## Why not Apple Music's own import

Apple Music's CD import names tracks from its own lookup, which for many
discs repeats the release name on every title ("Intro (live at Foro Sol
(Mexico City) 21/23/25.09.23)"), files each disc of a set as its own album
("M" and "M [Disc 2]"), guesses artwork that is often for a different album,
and never checks the rip or keeps a lossless copy. This skill does all of it
itself. **If Apple Music starts importing the disc on its own, tell the user
to cancel that import first**; to stop it for good, Music > Settings >
General > "When a CD is inserted" > "Show CD".

## Setup

```bash
bash ../setup/scripts/check-config.sh
```

Needs `library_import`, `library_storage` and `archive_workdir`. Uses
`cd_read_offset` (the drive's read offset in samples) and `work_dir` (where
temporary work goes) when set. If a
required key is `missing`, stop and run the `setup` skill.

Then check the tools:

```bash
bash scripts/check-deps.sh
```

If `ok` is false, **stop**. Tell the user which tools are missing and the
`install_command`, and offer to run it. Run it only when they say yes; never
rip with a tool missing.

## Running the scripts

Scripts are in `scripts/` in this skill's base directory. Run each one as a
single command by its **absolute path**, with no redirect, pipe or `&&`, and
save JSON with the script's own `--out FILE`:

```bash
bash /abs/path/to/skills/rip-cd/scripts/read-disc.sh --out "$WORK/disc.json"
```

The plugin's safety hook auto-approves exactly that shape; anything else
(`> file.json`, `| jq`, a relative `scripts/...` path) asks the user every
time. Below, `scripts/x.sh` is shorthand for that absolute path.

Work in one temporary folder per release, `$WORK`, from
`scripts/work-dir.sh "<name>"` (its `work_dir`): `cd-rip` while the release
is unknown, `cd-rip-<Artist> - <Album>` once a set's first disc is chosen
(keep using whichever folder the set started in). It lives under the
system's temp folder, never in Downloads or the user's home: nothing in it
is the only copy of anything once a disc is archived, because the release
record and cover go to the NAS with the WAVs.

## Scripts

- **`work-dir.sh <name>`**: the temporary work folder for a release.
- **`check-deps.sh`**: are cd-paranoia, ffmpeg (with LAME), python3, curl and jq installed.
- **`read-disc.sh`**: the disc's table of contents, its MusicBrainz disc ID and AccurateRip IDs (computed locally), and any names macOS shows for it, with repeated suffixes found.
- **`lookup-release.sh <disc.json>`**: every MusicBrainz release that disc belongs to.
- **`make-release-record.sh --release-id ID --genre G [...]`**: the release record (`release.json`) all later steps read.
- **`fetch-cover.sh <release_id> <cover.jpg>`**: the front cover from the Cover Art Archive, padded square.
- **`rip-disc.sh <dir> --offset N`**: secure rip to `01.wav`, `02.wav`, ...
- **`verify-accuraterip.sh <dir> <disc.json>`**: checksums against AccurateRip.
- **`encode-release.sh <dir> <release.json> <disc> <out> --cover cover.jpg`**: `mp3/` (320 kbps, tagged, cover embedded) and `wav/` (the rip, untouched, renamed, plus release.json and cover.jpg).
- **`update-record.sh <release.json> --disc N [--accuraterip S] [--discid ID] [--title N=T]`**: record a disc's verdict, ID or a corrected title, in the record and its copies in the work folder.
- **`eject-disc.sh`**: eject the disc.

Every script takes `--help`.

## Workflow

### Step 1: Identify the disc

```bash
bash scripts/read-disc.sh --out "$WORK/disc.json"
bash scripts/lookup-release.sh "$WORK/disc.json" --out "$WORK/lookup.json"
```

Exit 2 from read-disc means no disc: ask the user to insert one.

As soon as the lookup returns, **tell the user what the disc is**: artist,
album, which disc of how many, and track count ("This is Night Drive -
Afterglow Live, disc 1, 3 tracks"). When several releases carry the disc,
say so in the same breath and that the barcode on the back of the case tells
them apart (Step 3, question 1). Every message that asks a question repeats
the disc's name, so the user never has to scroll back to know which disc
the question is about.

**Is this a later disc of a release already started?** Look for a
`release.json` whose discs list this disc ID in `known_discids` or
`mb_discid`: in `$ARCHIVE_WORKDIR/to_nas/wav/*/*/release.json` (Glob) and in
the work folders beside `$WORK`. If one matches, say so ("this is disc 2 of
M, which you ripped on 19 Oct"), **reuse that record's answers** (no
questions in Step 3) and record the disc's ID:
`scripts/update-record.sh "$RECORD" --disc N --discid "$DISCID"`. When the
match is on the NAS only, copy that record into `$WORK` with the Read and
Write tools first. Every disc of a release must carry
identical Album, Album Artist and disc total, or Apple Music splits the
release into several albums.

### Step 2: Start the rip

The rip needs no answers, so start it now and ask the questions while it
runs (15-25 minutes for a full CD). Run it in the background
(`run_in_background`), and tell the user it is running:

```bash
bash scripts/rip-disc.sh "$WORK/rip-disc$N" --offset "$CD_READ_OFFSET" --out "$WORK/rip-disc$N.json"
```

`$N` is which disc of the release this is; until the release is chosen, use
the candidate's `audio_disc`. "405: Option not supported by drive" in its
output is the drive declining an optional speed command and is harmless.

If `cd_read_offset` is not configured, say the AccurateRip check will
probably fail until it is, and rip with 0: the rip is still secure. The
offset for a drive model is in AccurateRip's drive list; once a rip verifies
with it, add it to config.json as `cd_read_offset`.

### Step 3: Ask the questions, one at a time

Wait for each answer before asking the next. Show concrete values, never a
template. **Answers the user already gave count**: an edition named in their
message ("the 2-CD edition", "the box set", a barcode), a genre, a title
choice. Take those and ask only what is still open; never ask for the
barcode when they have said which edition. Ask a question only when there
is a real choice to make; otherwise state the value and move on.

1. **Which release** (only when `lookup.json` has several candidates and
   the user has not already said which): first name the disc, artist and
   album ("This is Night Drive - Afterglow Live"), then show each edition
   (what it holds, e.g. "DVD + 2 CDs"), country, date and barcode, since
   the barcode on the case settles it. Box sets list Blu-rays and DVDs too; the
   disc tags count audio CDs only (`audio_disc` of `audio_disc_total`).
2. **Album title**: MusicBrainz's, stated, not asked. Ask only when there
   is a real alternative: the user's library names related albums
   differently (check with `../audit-release/scripts/music-tracks.sh
   --artist "<artist>"`), e.g. its title case against MusicBrainz's lower
   case.
3. **Track titles**: only when there is a real choice. Show the differing
   titles side by side:
   - MusicBrainz leaves versions out of titles ("In Your Room" for the
     Zephyr Mix) and uses its own capitalization. When macOS showed names
     for the disc (`mac_titles`), offer those with the release-wide suffix
     stripped as the alternative. Strip a suffix that describes the whole
     release ("(live at ...)"); keep one that tells tracks apart ("(Memento
     Mori Sessions)" on four bonus tracks).
   - Typographic punctuation: MusicBrainz writes "True Faith‐94" with a
     Unicode hyphen (U+2010), which a search for "-94" does not find. Check
     the titles **of the disc being ripped now** for ‐ – — ’ “ ” ″ and, if
     any has one, name those titles and offer plain punctuation, even when
     the user said to keep MusicBrainz's titles: they look the same. Titles
     on discs not ripped yet wait for their own disc (then change them with
     `update-record.sh --title`); do not hold this disc up for them.
4. **Genre**: never pick it. Offer numbered options: the genres the user's
   library uses for this artist, most used first (from music-tracks.sh),
   then the rest of the library's genres
   (`../manage-metadata/scripts/extract-apple-music-genres.sh`), or their own.
5. **Album Artist**: only ask when the tracks have more than one artist
   (see `../process-album/references/album-types.md`). Otherwise it is the
   artist. Always set it, even for a single artist: an empty Album Artist
   is one of the ways a later disc ends up as a separate album.

When MusicBrainz has no match (`"match": "none"`), build the titles from
`mac_titles.stripped` (or ask the user for them), and write the record by
hand in the same shape, with `mb_release_id: null`.

Then write the record and fetch the cover:

```bash
bash scripts/make-release-record.sh --release-id "$ID" --genre "$GENRE" \
  [--album "$ALBUM"] [--album-artist "$AA"] [--plain-punctuation] \
  [--titles-from titles.json] --discid "$N=$DISCID" --out "$WORK/release.json"
bash scripts/fetch-cover.sh "$ID" "$WORK/cover.jpg"
```

A `titles.json` for `--titles-from` is written with the Write tool. MusicBrainz
allows one request a second; the scripts retry its "503" themselves.

Show the user the cover (Read the image). The Archive's primary front is
sometimes a photo of a shrink-wrapped box; if it looks wrong, say so. Never
let Apple Music pick artwork.

### Step 4: Verify the rip

When the rip finishes (exit 3 means a track could not be read cleanly: stop
and suggest cleaning the disc):

```bash
bash scripts/verify-accuraterip.sh "$WORK/rip-disc$N" "$WORK/disc.json" --out "$WORK/verify-disc$N.json"
```

- `verified`: every track matched; say how many other rips agreed.
- `not_in_database`: nobody has submitted this pressing; the rip is still
  secure, just not cross-checked. Carry on.
- `partial`: name the tracks that did not match. Those may be damaged
  (re-rip them with `--tracks`) or simply rare. Ask before carrying on.
- `mismatch`: no track matched, nearly always a wrong `cd_read_offset`.
  Stop and say so.

Record the verdict, so the NAS copy says the rip was checked:

```bash
bash scripts/update-record.sh "$WORK/release.json" --disc "$N" --accuraterip verified
```

### Step 5: Encode

```bash
bash scripts/encode-release.sh "$WORK/rip-disc$N" "$WORK/release.json" "$N" "$WORK/disc$N" \
  --cover "$WORK/cover.jpg"
```

Both formats come from the one verified rip: the WAVs are its audio
untouched, the MP3s are encoded from it.

### Step 6: Import the MP3s

**First, is the release already in Apple Music?** (A re-rip to replace a bad
import, or an earlier attempt.) Check with
`../audit-release/scripts/music-tracks.sh --artist "$ARTIST"` and look for
this album under any of its names ("M", "M [Disc 2]"). If it is there and
no snapshot exists yet, save one **before importing**, so the old tracks
can be told apart from the new ones later:
`../audit-release/scripts/music-tracks.sh --artist "$ARTIST" --album "<name>" [--album ...] --out "$WORK/old-tracks.json"`,
and tell the user it was saved. Removing them later is `audit-release`'s
job (see "Replacing an old import" below).

→ `Skill("media-management:import-to-apple-music", args="$WORK/disc$N/mp3")`

Its script takes `--wait 120`: use it, so the audit below sees the new
tracks. Apple Music may take a few seconds per disc. Then ask the user to check Apple Music: one album, the right cover, the right
disc number. **Do not continue until they confirm.** That message always
summarizes, in this order: which disc of which release ("disc 2 of 2 of
Night Drive - Afterglow Live", and for a later disc that its answers came
from the record saved with disc 1), the AccurateRip verdict ("3 of 3 tracks
verified"), what went into Apple Music, and what comes next. Then confirm it with the
audit (read-only):

```bash
bash ../audit-release/scripts/audit-release.sh --artist "$ARTIST" --album "$ALBUM" \
  --release "$WORK/release.json" --out "$WORK/audit.json"
```

Every check about Apple Music and the files must pass (`one_album`,
`album_artist`, `disc_tags`, `clean_titles`, `release_id`, `artwork`,
`mp3_320`). `complete` fails until every disc of a set is imported, and the
NAS checks until this disc is archived; both are expected. Anything else
failing: use the `audit-release` skill to repair it before archiving.

**If the user corrects a title now**, change it in the record
(`update-record.sh --title N=...`), then plan and apply it in Apple Music with
`../audit-release/scripts/repair-release.sh`, and re-run Step 5 with
`--wav-only` so the WAV names match.

### Step 7: Archive to the NAS

→ `Skill("media-management:archive-media", args="mp3 \"$AA_FOLDER\" \"$ALBUM_FOLDER\"")`
→ `Skill("media-management:archive-media", args="wav \"$AA_FOLDER\" \"$ALBUM_FOLDER\" \"$WORK/disc$N/wav\"")`

Use the folder names Apple Music actually used (the audit's
`paths.library_folders`): it writes ":", "/" and other characters as "_".
The MP3 archive re-copies the whole album from Apple Music, which is fine:
earlier discs are overwritten with the same files. The WAV archive adds this
disc to the folder, with `release.json` and `cover.jpg`; its `verified`
checks this disc's files, so earlier discs already there do not count
against it.

### Replacing an old import

When the rip replaces an earlier import of the same release (the user asked
to "replace" a bad import), removing the old tracks is **not this skill's
job**: hand over to the `audit-release` skill (its Step 6), which shows the
exact tracks first and removes nothing without a yes to that list. Never
run its `remove-tracks.sh --confirm` from here.

### Step 8: Next disc, and cleanup

If the release has more discs, ask the user to insert the next one and go
back to Step 1, which will recognise it. Otherwise, or when the user stops:

- Once the audit passes, say how big `$WORK` is (several GB for a box set:
  every rip and encode) and offer to delete it. Delete only with a yes. An
  unfinished set loses nothing either way: its record is on the NAS.
- Offer to eject: `scripts/eject-disc.sh`.
