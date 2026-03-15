---
name: split-long-tracks
description: >-
  Split audio tracks exceeding 78 minutes at silence points with crossfades.
  Use when tracks are too long for Apple Music.
allowed-tools: Bash Read
metadata:
  author: eyelock
  version: "0.2.0"
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

**DO NOT PROCEED without user confirmation.**

### Step 3: Split

Run the split script on the folder:
```bash
bash scripts/split-long-tracks.sh "$FOLDER" 78
```

The script:
- Uses `silencedetect` to find quiet sections
- Splits at the silence point closest to even division
- Applies 2s fade in/out at each split boundary
- Names output files sequentially (01, 02, ...)
- Removes the original file after successful split

### Step 4: Update track count

After splitting, the folder has new files. Delegate to the manage-metadata
skill to re-run track count update on the folder.

### Step 5: Report

Present the split results: how many parts each track was split into, with durations.
