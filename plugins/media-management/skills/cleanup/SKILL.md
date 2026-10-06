---
name: cleanup
description: >-
  Tidy Downloads after a release is fully processed: move its ZIPs (or loose
  single-track files) to processed/ and delete its extraction folders, after
  showing the list and getting confirmation. Use when the user is done with an
  album and wants its leftovers cleared ("tidy up my downloads for X", "remove
  the extracted folders"), not for general Downloads housekeeping.
allowed-tools: Bash Read
---

## Setup

Resolve paths with the setup skill's checker, which applies the plugin's one
resolution order (the `MEDIA_MGMT_*` env var first, then config.json at
`$MEDIA_MGMT_CONFIG_PATH`, default `~/.config/media-management/config.json`):

```bash
bash ../setup/scripts/check-config.sh
```

This skill needs `downloads`, plus `processed` if it is set (where archived ZIPs
go; default `<downloads>/processed`): use each item's `value` from the JSON. If
a key it needs is `missing`, stop and run the `setup` skill rather than guessing
a path. When the user names a folder explicitly, use that folder.

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

Only items whose name is the release name plus a store or browser duplicate
suffix (`-2`, `-wav`, ` (1)`, ` (pre-order)`) match. Anything else that merely
starts with the same words, such as `Artist - Album (Remixes).zip`, is a
different release: leave it alone, and mention it only so the user knows it was
not touched.

If nothing is found, report this and exit without moving or deleting anything.
If nothing matches but similarly named items exist (the user said
`Artist - Album` and Downloads holds `Artist - Album EP.zip`), list them and
ask which release they meant. Never clean up a near match on your own, even
when the request says to go ahead.

### Step 2: Ask for confirmation

> **Shall I proceed with cleanup?** (This will move ZIPs/audio files to processed/ and delete extraction folders)

**DO NOT PROCEED without explicit user confirmation.** Explicit means the user
said yes to this cleanup: in a reply, or in the request itself when it plainly
authorizes it without a further check ("go ahead, no need to confirm"). A
request that only asks you to tidy up is not confirmation: present the list and
stop.

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
