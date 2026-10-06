---
name: import-to-apple-music
description: >-
  Copy finished MP3s into Apple Music via the auto-import folder and verify
  the album lands correctly. Use once metadata is finalized and the user
  wants tracks added to their library — e.g. "add this to Apple Music" or
  "import these tracks" — even if they don't say "auto-import" explicitly.
  Also use to diagnose a bad import, e.g. "it showed up as separate tracks
  instead of one album."
allowed-tools: Bash Read
---

## Setup

Resolve paths with the setup skill's checker, which applies the plugin's one
resolution order (the `MEDIA_MGMT_*` env var first, then config.json at
`$MEDIA_MGMT_CONFIG_PATH`, default `~/.config/media-management/config.json`):

```bash
bash ../setup/scripts/check-config.sh
```

This skill needs `library_import` (the Apple Music auto-import folder): use each
item's `value` from the JSON. If a key it needs is `missing`, stop and run the
`setup` skill rather than guessing a path. When the user names a folder
explicitly, use that folder.

Scripts are in `scripts/` relative to this skill directory.

## Scripts

- **`import-mp3s.sh <source_folder> <import_folder>`** — Validate source and import folders, copy all MP3s, output JSON with results. Run `--help` for details.

## Workflow

### Step 0: Check what is being imported

Only MP3s go to Apple Music. If the folder holds only WAVs (or FLACs), or the
user asks to import the lossless files, do not copy them: explain that WAVs
never go through Apple Music (the library already gets the MP3s, so they would
be duplicates, and lossless copies belong on the NAS) and offer the
`archive-media` skill's WAV mode instead. Other files in the folder (cover.jpg,
PDFs) are never copied.

If the user reports a bad import rather than asking for one, go to Step 3: do
not copy the same files again before the metadata is fixed.

### Step 1: Import MP3s

Run the import script with the resolved paths:
```bash
bash scripts/import-mp3s.sh "$SOURCE_FOLDER" "$LIBRARY_IMPORT"
```

The script validates both folders exist, copies all MP3 files, and reports the count and file list as JSON.

### Step 2: Wait for import

Apple Music picks up files from the auto-import folder automatically. This may take a few seconds.

Tell the user:
> Files have been copied to the Apple Music auto-import folder.
> Please open Apple Music and verify the album appears correctly:
> - All tracks show as a single album (not individual items)
> - Artist and album names are correct
> - Track order is correct
>
> **Confirm when the import looks good, or tell me what needs fixing.**

### Step 3: Handle issues

If the user reports problems:
- **Tracks appear as separate items or albums:** Album or Album Artist metadata is
  inconsistent. Inspect the folder with the `manage-metadata` skill: a
  multi-artist release with no Album Artist is filed under each track's artist
  (a compilation needs Album Artist "Various Artists" and the compilation flag).
  Offer to fix the metadata, then remove the stray copies from Apple Music and
  re-import. Do not re-copy the files until the metadata is fixed.
- **Wrong genre/artist:** Offer to update metadata and re-import.
- **Files not appearing:** Check if files are still in the auto-import folder (they get moved after import). If still there, Apple Music may need a restart.

### Important

- Only import MP3 files. WAVs NEVER go through Apple Music import.
- Do NOT proceed with archival until the user explicitly confirms the import is correct.
