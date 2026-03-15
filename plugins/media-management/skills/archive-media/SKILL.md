---
name: archive-media
description: >-
  Copy processed MP3s and WAVs to NAS storage. Use after Apple Music import
  or when re-archiving corrected files.
allowed-tools: Bash Read
metadata:
  author: eyelock
  version: "0.3.0"
---

## Setup

1. Check environment variables: MEDIA_MGMT_LIBRARY_STORAGE, MEDIA_MGMT_ARCHIVE_WORKDIR
2. If unset, use default paths from CLAUDE.md
3. If CLAUDE.md has no paths, read config.json from the project root

Scripts are in `scripts/` relative to this skill directory.

## Scripts

- **`archive-files.sh <mode> <source_dir> <dest_dir>`** — Copy audio files to destination, verify counts. For WAV mode, calls rename-wav-files.sh internally. Run `--help` for details.
- **`rename-wav-files.sh <folder>`** — Rename WAV files from vendor format to clean format. Called internally by archive-files.sh.

## Argument format

```
mp3 <artist> <album>
wav <artist> <album> <source_folder>
```

- **mp3**: Archives from Apple Music library (`$LIBRARY_STORAGE/Artist/Album/`)
- **wav**: Archives from extraction folder, skips Apple Music entirely

## Workflow

Determine mode from the first argument: `mp3` or `wav`.

### MP3 Archival

Source is the Apple Music library (captures any edits made in Apple Music).

Run the archive script:
```bash
bash scripts/archive-files.sh mp3 "$LIBRARY_STORAGE/$ARTIST/$ALBUM" "$ARCHIVE_WORKDIR/to_nas/mp3/$ARTIST/$ALBUM"
```

The script creates the destination, copies all MP3 files, verifies the count matches, and outputs JSON with results.

Check the JSON output: if `verified` is `false`, warn the user about the count mismatch.

### WAV Archival

Source is the extraction folder. WAVs NEVER go through Apple Music.

Run the archive script:
```bash
bash scripts/archive-files.sh wav "$SOURCE_FOLDER" "$ARCHIVE_WORKDIR/to_nas/wav/$ARTIST/$ALBUM"
```

The script creates the destination, copies all WAV files, runs rename-wav-files.sh to clean up vendor filenames, verifies the count, and outputs JSON with results.

Check the JSON output: if `renamed` is `false`, warn the user that renaming may have failed.
