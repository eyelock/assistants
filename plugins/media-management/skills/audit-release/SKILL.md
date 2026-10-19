---
name: audit-release
description: >-
  Check a release already in Apple Music against everything a finished
  import should be (one album, clean titles, real artwork, MP3s and WAVs on
  the NAS) and repair what is wrong in place: merge an album Apple Music
  split per disc ("M" and "M [Disc 2]"), strip repeated suffixes from titles,
  replace guessed artwork, or replace a half-done import. Use when the user
  says an album is split, shows the wrong cover, looks messy, or an import
  "didn't finish", asks to check an artist's albums for splits, asks to
  undo an album fix made earlier, or is replacing an old import ("carry on
  replacing it" after a re-rip). Not for importing a new CD (rip-cd) or a
  new download (process-album).
allowed-tools: Bash Read Write Skill
---

## Setup

```bash
bash ../setup/scripts/check-config.sh
```

Needs `library_storage`, `archive_workdir`, `downloads` and
`library_import`. If one is `missing`, stop and run the `setup` skill.

## Running the scripts

Scripts are in `scripts/` in this skill's base directory. Run each one as a
single command by its **absolute path**, with no redirect, pipe or `&&`, and
save JSON with its own `--out FILE`: the plugin's safety hook auto-approves
exactly that shape, and anything else asks the user every time. Below,
`scripts/x.sh` is shorthand for that absolute path. Keep plans, records and
snapshots in a temporary work folder from `rip-cd`'s
`work-dir.sh "audit-<Artist> - <Album>"`, never in Downloads or the home
folder. Keep a repair's plan until the user is happy: it is the undo.

- **`find-splits.sh --artist NAME [--deep]`**: an artist's albums that are really one release.
- **`music-tracks.sh --artist NAME [--album NAME ...]`**: what Apple Music has, with the tags that decide album grouping.
- **`audit-release.sh --artist NAME --album NAME [--album ...] [--release FILE]`**: the checklist below. Read-only.
- **`repair-release.sh plan|apply|revert`**: retag in place through Apple Music, with an undo.
- **`remove-tracks.sh <snapshot.json> [--confirm]`**: remove an old import once its replacement is in.

## Workflow

### Step 1: Find what to audit

If the user names an album, find every album it is split across: run
`find-splits.sh --artist "<artist>"` and take the matching split's
`audit_args`. If they ask about an artist, show every split it found and
ask which to work on, one at a time. `--deep` also matches by MusicBrainz
release ID; it reads every file, so use it only when the quick pass finds
nothing the user expected.

### Step 2: Audit

```bash
bash scripts/audit-release.sh --artist "$ARTIST" --album "$A1" --album "$A2" --out "$WORK/audit.json"
```

Show the result as a table of checks, ✅ or ❌ with the detail, then the
`fixes` it proposes, in order:

| Fix | For | How |
|---|---|---|
| `retag` | one_album, album_artist, disc_tags, clean_titles, release_id, artwork | Steps 3-5 |
| `rip_wav` | nas_wav, rip_verified | The `rip-cd` skill with the release's discs, WAVs only (encode with `--wav-only`) |
| `archive_mp3` | nas_mp3 | `archive-media` mp3 mode, with the audit's `paths.library_folders` |
| `remove_leftovers` | no_leftovers | The `cleanup` skill |
| `replace` | mp3_320, files_present, or the user prefers it | Step 6 |

When the release came from a CD and the MP3s are fine, offer the choice:
**repair** (retag in place, rip only the WAVs) or **replace** (re-rip
everything, so the MP3s come from the same verified rip as the WAVs).

### Step 3: Build the release record

The repair needs the confirmed metadata: a release record, as `rip-cd`
writes it. If the NAS WAV folder already has a `release.json`, use it. If
not, find the release on MusicBrainz (with the disc in the drive, `rip-cd`'s
`read-disc.sh` and `lookup-release.sh`; without it, ask the user for the
release or search MusicBrainz by artist and album) and ask the same
questions `rip-cd` asks, one at a time: which release (box set or
standalone), album title, track titles, genre. For titles, show the
existing Apple Music titles with the repeated suffix stripped beside
MusicBrainz's, since MusicBrainz leaves out version names ("Zephyr Mix")
the existing titles often have; write the user's choice with the Write tool
as a `titles.json` for `make-release-record.sh --titles-from`. Never pick the
genre. Then fetch the cover with `rip-cd`'s `fetch-cover.sh` and show it:
Apple Music's own artwork guesses for CD imports are often for another
album, and live only in its cache, never in the files.

### Step 4: Plan, and confirm

```bash
bash scripts/repair-release.sh plan --artist "$ARTIST" --album "$A1" --album "$A2" \
  --release "$WORK/release.json" --cover "$WORK/cover.jpg" --out "$WORK/plan.json"
```

Show the `summary` as a before → after table, a few example tracks, and any
`warnings` (a track whose length differs from the record's by more than 3
seconds is left out: it may be a different recording), `unmatched_tracks`
and `missing_from_library`. Say that `revert` with the same plan restores
everything except Apple Music's own artwork guess. **Apply only when the
user agrees.**

### Step 5: Apply and check

```bash
bash scripts/repair-release.sh apply "$WORK/plan.json"
bash scripts/audit-release.sh --artist "$ARTIST" --album "$NEW_ALBUM" --release "$WORK/release.json"
```

Apple Music rewrites the files' tags and, when it organizes the library,
moves them into the new album folder. Audit the new album name: the
Apple Music checks must all pass now. Ask the user to look in Apple Music;
after they confirm, run the remaining fixes (`archive_mp3`, `rip_wav`).
Undo: `repair-release.sh revert "$WORK/plan.json"`.

### Undoing an earlier repair

When the user asks to undo a fix ("put it back how it was"), find its plan:
`plan.json` in the work folders, `<work_dir>/audit-<Artist> - <Album>/` (the
base is `rip-cd`'s `work-dir.sh` output's `base`; Glob it for
`audit-*/plan.json`, newest first). Show what the revert will restore (the
plan's `before` values), then run `repair-release.sh revert` with it.
Never rebuild the old values by hand; if no plan survives (the temp folder
was cleared), say so and offer to retag from what the user remembers.

### Step 6: Replace a bad import

1. Snapshot the old tracks **before** anything new is imported:
   `scripts/music-tracks.sh --artist "$ARTIST" --album "$A1" --album "$A2" --out "$WORK/old-tracks.json"`.
2. Import the release again through `rip-cd` (or `process-album` for a
   download). The new tracks may land in the same album: that is expected.
3. Once the new import's audit passes, dry-run the removal **for the discs
   re-imported so far** and show it as a list (album, disc-track, title):
   `scripts/remove-tracks.sh "$WORK/old-tracks.json" --disc 1`. A disc not
   re-ripped yet keeps its old tracks until its new ones are in: never
   offer to remove a disc that would then have no copy.
4. **Stop and ask**: "Remove these 3 tracks? Their files go to the Trash."
   Only an explicit yes to that list counts. "Carry on", "replace it" or
   "looks right" said before the list was shown is permission to get this
   far, not to delete. On the yes: the same command with
   `--confirm <confirm_token>` from the dry run. It deletes only those
   tracks and moves their files to the Trash. Audit again, archive the MP3s
   again, and repeat for the next disc.
