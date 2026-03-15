---
name: import-to-apple-music
description: >-
  Import MP3 files into Apple Music via auto-import folder. Use when importing
  music to Apple Music library.
allowed-tools: Bash Read
metadata:
  author: eyelock
  version: "0.2.0"
---

## Setup

1. Check environment variable: MEDIA_MGMT_LIBRARY_IMPORT
2. If unset, use the default Apple Music import path from CLAUDE.md
3. If CLAUDE.md has no path, read config.json from the project root

Scripts are in `scripts/` relative to this skill directory.

## Scripts

- **`import-mp3s.sh <source_folder> <import_folder>`** — Validate source and import folders, copy all MP3s, output JSON with results. Run `--help` for details.

## Workflow

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
- **Tracks appear as separate items:** Album or Album Artist metadata may be inconsistent. Offer to re-inspect and fix metadata, then re-import.
- **Wrong genre/artist:** Offer to update metadata and re-import.
- **Files not appearing:** Check if files are still in the auto-import folder (they get moved after import). If still there, Apple Music may need a restart.

### Important

- Only import MP3 files. WAVs NEVER go through Apple Music import.
- Do NOT proceed with archival until the user explicitly confirms the import is correct.
