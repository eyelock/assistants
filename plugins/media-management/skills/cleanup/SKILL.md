---
name: cleanup
description: >-
  Move processed ZIPs and loose single-track audio files to archive and
  clean up extraction folders. Use after album processing is complete.
allowed-tools: Bash Read
---

## Setup

1. Check environment variable: MEDIA_MGMT_DOWNLOADS
2. If unset, use the default Downloads path from CLAUDE.md
3. If CLAUDE.md has no path, read config.json from $MEDIA_MGMT_CONFIG_PATH (defaults to ~/.config/media-management/config.json)

Scripts are in `scripts/` relative to this skill directory.

## Scripts

- **`find-release-artifacts.sh <downloads_folder> <release_name> [--zip <path>]... [--folder <path>]...`** — Find all ZIPs, loose audio files, and extraction folders related to a release. Run `--help` for details.
- **`cleanup-release.sh <downloads_folder> <release_name> [--zip <path>]... [--folder <path>]...`** — Move ZIPs and loose audio files to processed/, remove extraction folders. Run `--help` for details.

## Argument format

```
<Artist - Album> [--zip <path>]... [--folder <path>]...
```

`release_name` (`<Artist - Album>`) drives glob matching against `$DOWNLOADS` — use this for
ad hoc/manual cleanup requests where you don't already have exact paths.

**Prefer `--zip`/`--folder` with exact paths whenever the caller already knows them** — most
notably `process-album`, which tracked the original ZIP/file paths (Step 1) and extraction
folder paths (Steps 2 and 11) all along. Glob matching by name alone is unreliable: a vendor
ZIP's filename frequently does NOT match the clean release name used for the extraction folder
— e.g. a Various Artists compilation ZIP named after all 10 contributing artists
(`Artist One- Artist Two- ... - keep it deep (pre-order).zip`), extracted into a folder simply called
`keep it deep`. Matching on `"keep it deep"` alone finds the folder but misses the ZIP (and vice
versa for the vendor name). Passing the exact paths sidesteps this entirely. `release_name` can
be `""` in that case — it's used only as a display label.

Explicit and glob-matched results are merged and deduplicated by path, so it's safe to pass both.

## Workflow

### Step 1: Find items to clean

Run the find script to locate all related artifacts. If exact paths are known, pass them
explicitly instead of relying on `$RELEASE_NAME` alone:
```bash
bash scripts/find-release-artifacts.sh "$DOWNLOADS" "$RELEASE_NAME" \
  --zip "$MP3_SOURCE_PATH" --zip "$WAV_SOURCE_PATH" \
  --folder "$EXTRACTION_FOLDER" --folder "$WAV_EXTRACTION_FOLDER"
```

Parse the JSON output and present to user:

> **Files to archive:**
> - `Artist - Album.zip` → move to `processed/`
> - `Artist - Album-2.zip` → move to `processed/`
> - `Artist - Track.mp3` → move to `processed/` (loose single-track file)
>
> **Folders to remove:**
> - `Artist - Album/`
> - `Artist - Album-wav/`

If nothing is found, report this and exit.

### Step 2: Ask for confirmation

> **Shall I proceed with cleanup?** (This will move ZIPs/audio files to processed/ and delete extraction folders)

**DO NOT PROCEED without explicit user confirmation.**

### Step 3: Execute cleanup

Run the cleanup script, passing the same `--zip`/`--folder` arguments used in Step 1 if any:
```bash
bash scripts/cleanup-release.sh "$DOWNLOADS" "$RELEASE_NAME" \
  --zip "$MP3_SOURCE_PATH" --zip "$WAV_SOURCE_PATH" \
  --folder "$EXTRACTION_FOLDER" --folder "$WAV_EXTRACTION_FOLDER"
```

The script moves ZIPs and loose audio files to `processed/`, removes extraction folders, and outputs JSON with results.

### Step 4: Report

Present the JSON results: how many ZIPs/audio files archived and folders removed.
