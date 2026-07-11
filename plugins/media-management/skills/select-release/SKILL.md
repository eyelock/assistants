---
name: select-release
description: >-
  Find music release ZIPs AND loose single-track audio files in Downloads
  and classify each as MP3 or WAV by inspecting contents (never filenames),
  matching pairs by release name. Use to see what's available to process —
  e.g. "what did I just buy" or "what's in my downloads" — even if the user
  doesn't mention ZIPs or file formats directly.
allowed-tools: Bash Read
metadata:
  author: eyelock
  version: "0.3.0"
---

## Setup

1. Check environment variable: MEDIA_MGMT_DOWNLOADS
2. If unset, use the default Downloads path from CLAUDE.md
3. If CLAUDE.md has no path, read config.json from $MEDIA_MGMT_CONFIG_PATH (defaults to ~/.config/media-management/config.json)

Scripts are in `scripts/` relative to this skill directory.

## Scripts

This skill has three scripts in `scripts/`:

- **`find-releases.sh <downloads_folder>`** — Find all ZIPs and loose audio files, inspect each, match into MP3/WAV pairs. This is the main entry point.
- **`inspect-zip.sh <zip_file>`** — Inspect a single ZIP and classify as MP3/WAV. Called internally by find-releases.sh.
- **`inspect-audio-file.sh <audio_file>`** — Inspect a single loose (non-ZIP) audio file and classify as MP3/WAV. Called internally by find-releases.sh, for single-track purchases that come as a bare file with no ZIP wrapper.

Run `--help` on any script for full usage details.

## Workflow

### Step 1: Find and classify releases

Run the find-releases script with the resolved downloads path:
```bash
bash scripts/find-releases.sh "$DOWNLOADS_PATH"
```

This will:
- Find all ZIP files AND loose `.mp3`/`.wav`/`.flac` files directly in the downloads folder (single-track purchases with no ZIP)
- Inspect each source's contents (file extensions, not filename) to classify as MP3 or WAV
- Match sources into release pairs by base name — a ZIP and a loose file can pair with each other, and two loose files (e.g. `Track.mp3` + `Track.wav`) pair the same way ZIPs do
- Output JSON with all releases; each release has `mp3_source`/`wav_source` objects, each carrying a `source_type` of `"zip"` or `"file"`

### Step 2: Present findings to user

Parse the JSON output and present as a table:

| # | Release | MP3 Source | WAV Source | MP3 Tracks | WAV Tracks |
|---|---------|------------|------------|------------|------------|
| 1 | Artist - Album | Artist - Album.zip | Artist - Album-2.zip | 8 | 8 |
| 2 | Artist - Track | Artist - Track.mp3 (file) | Artist - Track.wav (file) | 1 | 1 |

Note in the table (or a footnote) when a source is a loose file rather than a ZIP, since the calling skill needs to branch on `source_type` when extracting/copying it.

If there are unmatched sources, list them separately.

### Step 3: Ask user to select

Ask: "Which release would you like to process?"

If there's only one release, confirm: "Found one release: Artist - Album. Process this one?"

Return the selected release info (`mp3_source`/`wav_source` objects — each with `path` and `source_type` — plus artist/album parsed from name) for the calling skill to use.
