---
name: manage-metadata
description: >-
  Inspect and update MP3 tags: genre, artist, album, track count, compilation
  flag. Use when checking or fixing music file metadata — including
  diagnostic questions like "why do these show up as separate tracks" or
  "is this folder's metadata consistent," not just explicit tag-editing
  requests.
allowed-tools: Bash Read
---

## Setup

Resolve paths with the setup skill's checker, which applies the plugin's one
resolution order (the `MEDIA_MGMT_*` env var first, then config.json at
`$MEDIA_MGMT_CONFIG_PATH`, default `~/.config/media-management/config.json`):

```bash
bash ../setup/scripts/check-config.sh
```

This skill needs `downloads` and `library_storage`, to locate the folder the
user means: use each item's `value` from the JSON. If a key it needs is
`missing`, stop and run the `setup` skill rather than guessing a path. When the
user names a folder explicitly, use that folder.

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
- Missing or empty genre, or genre that differs between tracks
- Inconsistent album names across tracks
- Inconsistent artist names across tracks
- Missing track numbers or wrong totals
- Album Artist set when it shouldn't be (single artist)
- Compilation flag inconsistencies

Then classify the album by its distinct track Artists, per
[album-types.md](../process-album/references/album-types.md), and say what its
Album Artist and compilation flag should be:
- **Single artist** (1 artist): Album Artist cleared, no compilation flag
- **Collaboration** (2 artists): Album Artist = the primary (most frequent)
  artist, no compilation flag, each track keeps its own Artist
- **Compilation** (3+ artists): Album Artist "Various Artists", compilation flag
  set, each track keeps its own Artist

Apple Music files an album by its Album Artist, falling back to each track's
Artist: a multi-artist album without the right Album Artist shows up as
separate albums. That is the usual answer to "why are these separate?".

## Update Mode

### Step 1: Inspect first

Always run inspect before updating. Present findings.

### Step 2: Ask what to update

Present the issues found and ask user to confirm what to fix. Never auto-apply
changes. Values the user already gave in the request ("set it to Techno", "make
Night Drive the album artist, go ahead") are confirmed: apply those without
asking again, but do not add fixes they did not ask for. A question ("why
does this show up as separate albums?") is not a request to change anything:
answer it, propose the fix, and ask.

### Step 3: Extract genres (if needed)

If genre needs setting and the user has not named one:
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

**Compilation:** (also sets Album Artist to "Various Artists")
```bash
bash scripts/set-compilation.sh "$FOLDER" true
```

Never change a track's own Artist to make an album group: the Album Artist
does that.

### Step 5: Verify

Run inspect again to confirm changes took effect:
```bash
bash scripts/inspect-metadata.sh "$FOLDER"
```

Present the updated table and confirm everything looks correct.
