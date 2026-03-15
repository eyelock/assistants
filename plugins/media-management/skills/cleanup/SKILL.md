---
name: cleanup
description: >-
  Move processed ZIPs to archive and clean up extraction folders. Use after
  album processing is complete.
allowed-tools: Bash Read
metadata:
  author: eyelock
  version: "0.3.0"
---

## Setup

1. Check environment variable: MEDIA_MGMT_DOWNLOADS
2. If unset, use the default Downloads path from CLAUDE.md
3. If CLAUDE.md has no path, read config.json from the project root

Scripts are in `scripts/` relative to this skill directory.

## Scripts

- **`find-release-artifacts.sh <downloads_folder> <release_name>`** — Find all ZIPs and extraction folders related to a release. Run `--help` for details.
- **`cleanup-release.sh <downloads_folder> <release_name>`** — Move ZIPs to processed/, remove extraction folders. Run `--help` for details.

## Argument format

```
<Artist - Album>
```

The release name is used to locate the related ZIP files and extraction folders in `$DOWNLOADS`.

## Workflow

### Step 1: Find items to clean

Run the find script to locate all related artifacts:
```bash
bash scripts/find-release-artifacts.sh "$DOWNLOADS" "$RELEASE_NAME"
```

Parse the JSON output and present to user:

> **Files to archive:**
> - `Artist - Album.zip` → move to `processed/`
> - `Artist - Album-2.zip` → move to `processed/`
>
> **Folders to remove:**
> - `Artist - Album/`
> - `Artist - Album-wav/`

If nothing is found, report this and exit.

### Step 2: Ask for confirmation

> **Shall I proceed with cleanup?** (This will move ZIPs to processed/ and delete extraction folders)

**DO NOT PROCEED without explicit user confirmation.**

### Step 3: Execute cleanup

Run the cleanup script:
```bash
bash scripts/cleanup-release.sh "$DOWNLOADS" "$RELEASE_NAME"
```

The script moves ZIPs to `processed/`, removes extraction folders, and outputs JSON with results.

### Step 4: Report

Present the JSON results: how many ZIPs archived and folders removed.
