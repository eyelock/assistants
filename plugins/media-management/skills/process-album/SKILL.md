---
name: process-album
description: >-
  End-to-end processing of downloaded music purchases: extract ZIPs (or copy
  loose single-track files), verify metadata, import to Apple Music, archive
  to NAS, clean up. Use when processing new music downloads.
allowed-tools: Bash Read Skill
metadata:
  author: eyelock
  version: "0.4.0"
---

## Delegation Rule

This skill is a pure orchestrator. It MUST invoke other skills using the Skill tool:

```
Skill("media-management:<skill-name>", args="<arguments>")
```

**DO NOT** call underlying scripts directly via Bash.
**DO NOT** re-implement sub-skill logic inline.
When a step says `→ Invoke:`, use the Skill tool exactly as shown.

The ONLY exception is Step 2 and Step 11 (getting the MP3/WAV source into a
working folder), which use this skill's own scripts.

## Setup

1. Check environment variables: MEDIA_MGMT_DOWNLOADS, MEDIA_MGMT_LIBRARY_IMPORT,
   MEDIA_MGMT_LIBRARY_STORAGE, MEDIA_MGMT_ARCHIVE_WORKDIR
2. For any unset variables, use the default paths from CLAUDE.md
3. If CLAUDE.md has no paths, read config.json from $MEDIA_MGMT_CONFIG_PATH (defaults to ~/.config/media-management/config.json)

Scripts are in `scripts/` relative to this skill directory.

## Scripts

- **`extract-zip.sh <zip_file> <dest_folder>`** — Extract a ZIP into a named subfolder with safety checks. Run `--help` for details.
- **`copy-file.sh <audio_file> <dest_folder>`** — Copy a loose (non-ZIP) audio file into a named subfolder, same safety checks as extract-zip.sh. Use this instead of extract-zip.sh when `select-release` reports `source_type: "file"` (a single-track purchase with no ZIP). Run `--help` for details.

## References

See [references/safety-rules.md](references/safety-rules.md) for critical safety rules.
See [references/album-types.md](references/album-types.md) for album classification.

## Workflow

### Phase 1: MP3 Processing

**Step 1: Identify release**
→ Invoke: `Skill("media-management:select-release")`
- If a release is specified in $ARGUMENTS, pass it as args
- NEVER trust filename suffixes — the skill inspects archive/file contents
- Note each source's `source_type` (`"zip"` or `"file"`) — it decides which script Step 2/Step 11 use

**Step 2: Get the MP3 source into a working folder**

If `mp3_source.source_type == "zip"`, extract it:
```bash
bash scripts/extract-zip.sh "$MP3_SOURCE_PATH" "$DOWNLOADS/$RELEASE_NAME"
```

If `mp3_source.source_type == "file"` (a loose single-track purchase, no ZIP), copy it instead:
```bash
bash scripts/copy-file.sh "$MP3_SOURCE_PATH" "$DOWNLOADS/$RELEASE_NAME"
```

Both scripts create the subfolder and output JSON with the resulting file list, so every later
step operates on `$EXTRACTION_FOLDER` the same way regardless of source type.
If either fails, ask user to move the file into the folder manually via Finder.

**Step 3: Inspect metadata**
→ Invoke: `Skill("media-management:manage-metadata", args="inspect $EXTRACTION_FOLDER")`
- Review the output for missing/inconsistent fields

**Step 4: MANDATORY metadata verification — STOP AND ASK USER**
- Present: track count, detected artist, album title
- Present numbered genre list from the inspect results, ask user to select or type custom
- Ask user to verify artist name
- Ask user to verify album title
- Check for multiple artists — if found, ask: "Is this a compilation?"
- See [references/album-types.md](references/album-types.md) for classification
- **DO NOT PROCEED without user confirmation of ALL fields**

**Step 5: Check for long tracks**
- Check duration of each MP3 (available from the inspect output)
- If any track > 78 minutes (4680 seconds), inform user and ask about splitting
→ If user confirms: `Skill("media-management:split-long-tracks", args="$EXTRACTION_FOLDER")`
- After splitting, update track count via manage-metadata

**Step 6: Update metadata**
→ Invoke: `Skill("media-management:manage-metadata", args="update $EXTRACTION_FOLDER genre=$GENRE clear-album-artist|set-album-artist=$ARTIST update-track-count")`
- Pass user-confirmed values (genre, album artist, compilation flag)

**Step 7: Import to Apple Music**
→ Invoke: `Skill("media-management:import-to-apple-music", args="$EXTRACTION_FOLDER")`

**Step 8: MANDATORY Apple Music verification — STOP AND ASK USER**
- Tell user: "Please check Apple Music and confirm the import looks correct"
- Check for: files appearing as a single album (not individual tracks)
- **DO NOT PROCEED until user confirms**

### Phase 2: NAS Staging

**Step 9: Archive MP3s**
→ Invoke: `Skill("media-management:archive-media", args="mp3 $ARTIST $ALBUM")`
- Source: `$LIBRARY_STORAGE/Artist/Album/` (from Apple Music, captures edits)
- Destination: `$ARCHIVE_WORKDIR/to_nas/mp3/Artist/Album/`

**Step 10: Verify MP3 archival**
- Check the JSON output from archive-media: `verified` should be `true`
- If not, warn user about count mismatch

### Phase 3: WAV Processing

**Step 11: Get the WAV source into a working folder**

If `wav_source.source_type == "zip"`, extract it:
```bash
bash scripts/extract-zip.sh "$WAV_SOURCE_PATH" "$DOWNLOADS/$RELEASE_NAME-wav"
```

If `wav_source.source_type == "file"`, copy it instead:
```bash
bash scripts/copy-file.sh "$WAV_SOURCE_PATH" "$DOWNLOADS/$RELEASE_NAME-wav"
```

**Step 12: Archive WAVs (SKIP Apple Music)**
→ Invoke: `Skill("media-management:archive-media", args="wav $ARTIST $ALBUM $WAV_EXTRACTION_FOLDER")`
- WAVs NEVER go through Apple Music import

**Step 13: Cleanup**
→ Invoke: `Skill("media-management:cleanup", args="$ARTIST - $ALBUM")`
- Moves original ZIPs/loose audio files to processed/, cleans extraction folders
