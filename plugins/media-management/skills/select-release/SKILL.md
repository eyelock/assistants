---
name: select-release
description: >-
  Find and identify music release ZIP files in Downloads, classifying MP3
  vs WAV. Use to see what music is available for processing.
allowed-tools: Bash Read
metadata:
  author: eyelock
  version: "0.2.0"
---

## Setup

1. Check environment variable: MEDIA_MGMT_DOWNLOADS
2. If unset, use the default Downloads path from CLAUDE.md
3. If CLAUDE.md has no path, read config.json from the project root

## Scripts

This skill has two scripts in `scripts/`:

- **`find-releases.sh <downloads_folder>`** — Find all ZIPs, inspect each, match into MP3/WAV pairs. This is the main entry point.
- **`inspect-zip.sh <zip_file>`** — Inspect a single ZIP and classify as MP3/WAV. Called internally by find-releases.sh.

Run `--help` on either script for full usage details.

## Workflow

### Step 1: Find and classify releases

Run the find-releases script with the resolved downloads path:
```bash
/Users/david/Storage/Workspace/mcp-servers/media-management/skills/select-release/scripts/find-releases.sh "$DOWNLOADS_PATH"
```

This will:
- Find all ZIP files in the downloads folder
- Inspect each ZIP's contents (file extensions, not filename) to classify as MP3 or WAV
- Match ZIPs into release pairs by base name
- Output JSON with all releases

### Step 2: Present findings to user

Parse the JSON output and present as a table:

| # | Release | MP3 ZIP | WAV ZIP | MP3 Tracks | WAV Tracks |
|---|---------|---------|---------|------------|------------|
| 1 | Artist - Album | Artist - Album.zip | Artist - Album-2.zip | 8 | 8 |

If there are unmatched ZIPs, list them separately.

### Step 3: Ask user to select

Ask: "Which release would you like to process?"

If there's only one release, confirm: "Found one release: Artist - Album. Process this one?"

Return the selected release info (both ZIP paths, detected type for each, artist/album parsed from name) for the calling skill to use.
