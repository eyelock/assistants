---
name: split-long-tracks
description: >-
  Find and split audio tracks longer than Apple Music's 78-minute limit at
  natural quiet points, keeping album order. Use when a DJ mix, live set or
  other long track is too long for Apple Music, or to check a folder for
  tracks over the limit.
allowed-tools: Bash Read
---

## Setup

Scripts are in `scripts/` relative to this skill directory.

## Scripts

- **`find-long-tracks.sh <folder> [max_minutes]`** — Scan all MP3s and report any exceeding the threshold (default: 78 min). Run `--help` for details.
- **`split-long-tracks.sh <file_or_folder> <max_minutes>`** — Split long tracks at silence points with crossfades. Run `--help` for details.

## Workflow

### Step 1: Identify long tracks

Run the find script to scan for tracks exceeding the threshold:
```bash
bash scripts/find-long-tracks.sh "$FOLDER"
```

If no long tracks are found (`long_tracks` array is empty), report this and exit.

### Step 2: Confirm with user

Present the long tracks and their durations from the JSON output.
Explain: "Files will be split at natural quiet points with 2-second fade transitions."

**DO NOT PROCEED without user confirmation.** The request itself counts only
when it plainly authorizes the split ("split it, no need to check with me");
a question such as "is anything too long?" is not confirmation.

### Step 3: Split

Run the split script on the folder:
```bash
bash scripts/split-long-tracks.sh "$FOLDER" 78
```

The script:
- Uses `silencedetect` to find quiet sections
- Splits at the silence point closest to even division
- Applies a 2s fade out and fade in at each cut it makes (the track's own start
  and end are untouched)
- Removes the original file after a successful split
- Names the parts without "Part X": a track alone in its folder becomes a
  mini-album (`01 Title.mp3`, `02 Title.mp3`, tagged 1/N); a track inside an
  album keeps its place (`03 Title 1.mp3`, `03 Title 2.mp3`, keeping its track
  number) so the album's order survives

### Step 4: Update track count

After splitting, the folder has new files. Renumber the whole folder with
manage-metadata's track-count update (`update-track-count.sh` in that skill's
`scripts/`), which keeps the album's order: by existing track number, then by
filename. Every track ends up `N/total`, the parts in sequence where the
original was.

### Step 5: Report

Present the split results: how many parts each track was split into, with durations.
