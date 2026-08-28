---
name: archive-media
description: >-
  Copy processed MP3s and WAVs to NAS storage. Use after Apple Music import
  or when re-archiving corrected files.
allowed-tools: Bash Read
metadata:
  author: eyelock
  version: "0.4.0"
---

## Setup

1. Check environment variables: MEDIA_MGMT_LIBRARY_STORAGE, MEDIA_MGMT_ARCHIVE_WORKDIR
2. If unset, use default paths from CLAUDE.md
3. If CLAUDE.md has no paths, read config.json from $MEDIA_MGMT_CONFIG_PATH (defaults to ~/.config/media-management/config.json)

Scripts are in `scripts/` relative to this skill directory.

## Scripts

- **`archive-files.sh <mode> <source_dir> <dest_dir>`** — Copy audio files to destination, verify counts. For WAV mode, calls rename-wav-files.sh internally. Run `--help` for details.
- **`rename-wav-files.sh <folder>`** — Rename WAV files from vendor format to clean format. Called internally by archive-files.sh.

## Argument format

```
mp3 <artist> <album>
wav <artist> <album> <source_folder>
```

- **mp3**: Archives from Apple Music library (`$LIBRARY_STORAGE/AlbumArtist/Album/`)
- **wav**: Archives from extraction folder, skips Apple Music entirely

## Workflow

Determine mode from the first argument: `mp3` or `wav`.

### MP3 Archival

Source is the Apple Music library (captures any edits made in Apple Music).

**Important — use the *effective Album Artist*, not the track Artist, for `$ARTIST` in the path below.**
Apple Music files an imported album on disk by its Album Artist tag, falling back to the
track Artist only when Album Artist is empty. Per [album-types.md](../process-album/references/album-types.md):
- **Single artist** (Album Artist cleared): folder = the track Artist — same as `$ARTIST` you'd expect
- **Collaboration** (Album Artist = primary artist): folder = that primary artist, not whichever artist happened to be first alphabetically
- **Compilation** (Album Artist = "Various Artists"): folder = literally `Various Artists`, **not** the individual track's artist

Getting this wrong fails loudly (`source folder not found`) rather than silently, but avoid the
extra round-trip: pass whatever value you set as Album Artist during metadata update (Step 6 of
process-album), not the per-track Artist.

Run the archive script:
```bash
bash scripts/archive-files.sh mp3 "$LIBRARY_STORAGE/$ALBUM_ARTIST/$ALBUM" "$ARCHIVE_WORKDIR/to_nas/mp3/$ALBUM_ARTIST/$ALBUM"
```

The script creates the destination, copies all MP3 files, verifies the count matches, and outputs JSON with results.

Check the JSON output: if `verified` is `false`, warn the user about the count mismatch. If the
script instead errors with "source folder not found," the most likely cause is passing the track
Artist for a compilation/collaboration — retry with the Album Artist (e.g. "Various Artists")
instead.

### WAV Archival

Source is the extraction folder (not Apple Music — WAVs never go through it). There's no
filesystem lookup here, so no risk of the mp3-mode path issue above, but use the same
`$ALBUM_ARTIST` value you used for the MP3 archive so the mp3/ and wav/ trees under
`to_nas/` mirror each other (e.g. both filed under `Various Artists/Album` for a compilation).

Run the archive script:
```bash
bash scripts/archive-files.sh wav "$SOURCE_FOLDER" "$ARCHIVE_WORKDIR/to_nas/wav/$ALBUM_ARTIST/$ALBUM"
```

The script creates the destination, copies all WAV files, runs rename-wav-files.sh to clean up vendor filenames, verifies the count, and outputs JSON with results.

Check the JSON output: if `renamed` is `false`, warn the user that renaming may have failed.
