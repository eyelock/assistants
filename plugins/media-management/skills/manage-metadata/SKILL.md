---
name: manage-metadata
description: >-
  Inspect and update MP3 tags: genre, artist, album, track count, compilation
  flag. Use when checking or fixing music file metadata.
allowed-tools: Bash Read
metadata:
  author: eyelock
  version: "0.2.0"
---

## Setup

1. Check environment variables: MEDIA_MGMT_DOWNLOADS, MEDIA_MGMT_LIBRARY_STORAGE
2. If unset, use default paths from CLAUDE.md
3. If CLAUDE.md has no paths, read config.json from the project root

Scripts are in `scripts/` relative to this skill directory.

## Modes

Parse `$ARGUMENTS` to determine mode and parameters:
- **inspect** (or no mode specified): Read-only metadata inspection
- **update**: Inspect first, then update based on user choices

### Argument format

```
inspect <folder>
update <folder> [genre=<genre>] [clear-album-artist | set-album-artist=<name>] [set-compilation] [update-track-count]
```

When update arguments include pre-confirmed values (e.g. `genre=Electronic`), apply them
directly — do not re-ask the user for values already specified in the arguments.

## Inspect Mode

### Step 1: Run inspection

```bash
bash scripts/inspect-metadata.sh "$FOLDER"
```

### Step 2: Present results

Display metadata as a readable table:

| # | File | Title | Artist | Album | Genre | Track | Album Artist |
|---|------|-------|--------|-------|-------|-------|-------------|

### Step 3: Flag issues

Check for:
- Missing titles
- Missing or empty genre
- Inconsistent artist names across tracks
- Missing track numbers or wrong totals
- Album Artist set when it shouldn't be (single artist)
- Compilation flag inconsistencies

## Update Mode

### Step 1: Inspect first

Always run inspect before updating. Present findings.

### Step 2: Ask what to update

Present the issues found and ask user to confirm what to fix. Never auto-apply changes.

### Step 3: Extract genres (if needed)

If genre needs setting:
```bash
bash scripts/extract-apple-music-genres.sh
```

Present the genre list as numbered options. Ask user to select or type a custom genre.

### Step 4: Apply updates

Run the appropriate scripts based on user's choices:

**Track count:**
```bash
bash scripts/update-track-count.sh "$FOLDER"
```

**Genre:**
```bash
bash scripts/update-genre.sh "$FOLDER" "$GENRE"
```

**Album Artist (clear for single artist):**
```bash
bash scripts/clear-album-artist.sh "$FOLDER"
```

**Album Artist (set for collaboration):**
```bash
bash scripts/set-album-artist.sh "$FOLDER" "$ARTIST"
```

**Compilation:**
```bash
bash scripts/set-compilation.sh "$FOLDER" true
```

### Step 5: Verify

Run inspect again to confirm changes took effect:
```bash
bash scripts/inspect-metadata.sh "$FOLDER"
```

Present the updated table and confirm everything looks correct.
