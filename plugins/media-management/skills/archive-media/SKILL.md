---
name: archive-media
description: >-
  Stage a processed release on the NAS: copy its MP3s from the Apple Music
  library and its WAVs from the extraction folder into the NAS staging folder,
  with clean WAV names and a verified count. Use once an Apple Music import
  looks right ("stage it to the NAS", "archive the WAVs"), or to re-archive
  files corrected after archiving. Not for renaming or converting files in
  place outside an archive run.
allowed-tools: Bash Read
---

## Setup

Resolve paths with the setup skill's checker, which applies the plugin's one
resolution order (the `MEDIA_MGMT_*` env var first, then config.json at
`$MEDIA_MGMT_CONFIG_PATH`, default `~/.config/media-management/config.json`):

```bash
bash ../setup/scripts/check-config.sh
```

This skill needs `library_storage` (the Apple Music library) and
`archive_workdir` (the NAS staging folder): use each item's `value` from the
JSON. If a key it needs is `missing`, stop and run the `setup` skill rather than
guessing a path. When the user names a folder explicitly, use that folder.

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
