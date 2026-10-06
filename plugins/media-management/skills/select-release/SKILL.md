---
name: select-release
description: >-
  Find music release ZIPs AND loose single-track audio files in Downloads
  and classify each as MP3 or WAV by inspecting contents (never filenames),
  matching pairs by release name. Use to see what's available to process —
  e.g. "what did I just buy" or "what's in my downloads" — even if the user
  doesn't mention ZIPs or file formats directly.
allowed-tools: Bash Read
---

## Setup

Resolve paths with the setup skill's checker, which applies the plugin's one
resolution order (the `MEDIA_MGMT_*` env var first, then config.json at
`$MEDIA_MGMT_CONFIG_PATH`, default `~/.config/media-management/config.json`):

```bash
bash ../setup/scripts/check-config.sh
```

This skill needs `downloads`: use each item's `value` from the JSON. If a key it
needs is `missing`, stop and run the `setup` skill rather than guessing a path.
When the user names a folder explicitly, use that folder.

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

Then list, separately from the table:
- **One-sided releases**: a release whose `wav_source` (or `mp3_source`) is
  `null` was bought or downloaded in one format only. Say which side is
  missing; never invent the other file.
- **Duplicates** (`duplicates`): a second copy of a source, such as a ZIP
  downloaded twice (`Album (1).zip`). Say which copy the release uses and that
  the other is a duplicate.
- **Unmatched** (`unmatched`): ZIPs mixing MP3s and WAVs, which need a look.

The MP3/WAV label comes from what is inside each ZIP, never from its name: a
store may well name the WAV ZIP `Album.zip` and the MP3 ZIP `Album-2.zip`.
Count only the audio files. A ZIP packed by Finder carries a `__MACOSX/` tree
of `._` forks named like the tracks (`._01 Song.mp3`) and a `.DS_Store`: they
are not tracks, and `find-releases.sh` leaves them out, so its `tracks` is the
real count. If you list a ZIP yourself, drop them before counting.
Files already moved to `processed/` are finished releases and are not listed.

### Step 3: Ask user to select

Ask: "Which release would you like to process?"

If there's only one release, confirm: "Found one release: Artist - Album. Process this one?"

Return the selected release info (`mp3_source`/`wav_source` objects — each with `path` and `source_type` — plus artist/album parsed from name) for the calling skill to use.
