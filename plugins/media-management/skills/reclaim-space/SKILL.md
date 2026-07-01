---
name: reclaim-space
description: >-
  Reclaim local disk by offloading cloud-backed Apple Music downloads. Audit
  iCloud status, build an offload playlist that protects your DJ crates and
  lossless files, then Remove Download. Use when the Mac is low on disk.
allowed-tools: Bash Read
metadata:
  author: eyelock
  version: "0.1.0"
---

## Setup

This skill talks to the Apple Music app via AppleScript, so it requires macOS
with Music scriptable (the terminal must have Automation permission for Music —
macOS prompts once on first run).

There are no path environment variables to resolve; everything operates on the
Music library, not the filesystem.

Scripts are in `scripts/` relative to this skill directory.

## Scripts

- **`audit-library.sh [--keep-folder <name>]`** — Read-only. Reports the iCloud
  status histogram (how many tracks are cloud-backed vs Ineligible) and the
  playlists inside the keep folder. Run `--help` for details.
- **`build-offload-playlist.sh [options]`** — Creates a playlist of tracks that
  are safe to offload. Non-destructive (never removes downloads). Run `--help`.

## Concept

Apple Music can re-download any track whose iCloud status is **Matched**,
**Uploaded**, **Purchased**, or **Subscription** — so removing its *local
download* is reversible and frees disk. Tracks that are **Ineligible** (often
WAV/large lossless) have **no cloud copy**; removing those is permanent data
loss, so they must be excluded (those belong on the NAS — see `archive-media`).

Apple's Smart Playlist editor has no "is downloaded" condition, and its
automation cannot author Smart Playlist rules. The workaround: build a playlist
of everything *safe to offload*, then run **Remove Download** on the whole list
(a no-op on anything not currently downloaded, so it is always safe to run).

## Workflow

### Step 1: Audit — confirm Sync Library is on and see what's offloadable

```bash
bash scripts/audit-library.sh --keep-folder "Crates"
```

Present the JSON: the cloud-status histogram, the `cloud_safe` total, and the
keep-folder playlists. **Confirm with the user before going further:**

- If `sync_library_likely_on` is `false` (or `cloud_safe` is 0), STOP — Sync
  Library is off, nothing is in the cloud, and offloading would lose data.
- If `cloud_status.ineligible` is high, warn that those are local-only; they are
  excluded by the Kind filter below but worth archiving to the NAS.

### Step 2: Build the offload playlist

Ask the user for their protections, then build it:

```bash
bash scripts/build-offload-playlist.sh \
  --playlist "Offload — Cloud Safe" \
  --keep-folder "Crates" \
  --exclude-grouping "DJ" \
  --exclude-kind "WAV" \
  --replace
```

- `--keep-folder` protects every playlist inside that folder (e.g. recency
  crates and genre crates that feed Rekordbox).
- `--exclude-grouping` protects tracks tagged for active use (e.g. Grouping
  starting `DJ`).
- `--exclude-kind` protects local-only formats (default `WAV`).

This can take a few minutes on a large library — it adds tracks one at a time.
Report `in_playlist` and the `excluded` breakdown.

### Step 3: Free the space — MANDATORY user step, never automate

Tell the user to:
1. Open the playlist in Apple Music and **sanity-check the count** matches
   `in_playlist`.
2. **Test on a small batch first**: select ~50 tracks → right-click → **Remove
   Download** → confirm they show the cloud icon and still stream.
3. Once trusted: ⌘A → right-click → **Remove Download**.

**DO NOT** run Remove Download for the user via automation. Surface the count
and the magnitude (it can be most of the library) and let them pull the trigger.

## Auto-updating alternative

The built playlist is a snapshot — re-run Step 2 (with `--replace`) to refresh
it. For a hands-off, always-current version, build the Smart Playlist by hand
once using [references/smart-playlist-recipe.md](references/smart-playlist-recipe.md).
