---
name: process-album
description: >-
  End-to-end processing of downloaded music purchases: extract ZIPs (or copy
  loose single-track files), verify metadata, import to Apple Music, archive
  to NAS, clean up. Use when processing new music downloads.
allowed-tools: Bash Read Skill
---

## Delegation Rule

This skill is a pure orchestrator. It MUST invoke other skills using the Skill tool:

```
Skill("media-management:<skill-name>", args="<arguments>")
```

**DO NOT** call underlying scripts directly via Bash.
**DO NOT** re-implement sub-skill logic inline.
When a step says `→ Invoke:`, use the Skill tool exactly as shown.

The ONLY exceptions are the path check in Setup, and Step 2 and Step 11
(getting the MP3/WAV source into a working folder), which use this skill's own
scripts.

## Setup

Resolve paths with the setup skill's checker, which applies the plugin's one
resolution order (the `MEDIA_MGMT_*` env var first, then config.json at
`$MEDIA_MGMT_CONFIG_PATH`, default `~/.config/media-management/config.json`):

```bash
bash ../setup/scripts/check-config.sh
```

This skill needs `downloads`, `library_import`, `library_storage` and
`archive_workdir`: use each item's `value` from the JSON. If a key it needs is
`missing`, stop and run the `setup` skill rather than guessing a path. When the
user names a folder explicitly, use that folder.

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
- Present: track count, detected artist, album title, and the genre currently tagged
- Ask the user to choose the genre: present it as numbered options (the current tag, plus the
  genres in their library, which manage-metadata's update mode lists) or let them type one.
  Never pick it for them
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
→ Invoke: `Skill("media-management:manage-metadata", args="update $EXTRACTION_FOLDER genre=$GENRE clear-album-artist|set-album-artist=$ALBUM_ARTIST update-track-count")`
- Pass user-confirmed values (genre, album artist, compilation flag)
- Record `$ALBUM_ARTIST` for later steps: the track Artist for single-artist albums (Album Artist
  cleared), the confirmed primary artist for collaborations, or "Various Artists" for
  compilations — Steps 9, 12, and 13 all need this exact value, not the per-track Artist

**Step 7: Import to Apple Music**
→ Invoke: `Skill("media-management:import-to-apple-music", args="$EXTRACTION_FOLDER")`

**Step 8: MANDATORY Apple Music verification — STOP AND ASK USER**
- Tell user: "Please check Apple Music and confirm the import looks correct"
- Check for: files appearing as a single album (not individual tracks)
- **DO NOT PROCEED until user confirms**

### Phase 2: NAS Staging

**Step 9: Archive MP3s**
→ Invoke: `Skill("media-management:archive-media", args="mp3 $ALBUM_ARTIST $ALBUM")`
- `$ALBUM_ARTIST` is the value Apple Music actually filed the album under — the Album Artist tag
  set in Step 6 (e.g. "Various Artists" for a compilation), falling back to the track Artist only
  when Album Artist was cleared (single-artist case). **Do not use the track Artist for a
  compilation or collaboration** — see [archive-media's SKILL.md](../archive-media/SKILL.md#mp3-archival) for why.
- Source: `$LIBRARY_STORAGE/$ALBUM_ARTIST/Album/` (from Apple Music, captures edits)
- Destination: `$ARCHIVE_WORKDIR/to_nas/mp3/$ALBUM_ARTIST/Album/`

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
→ Invoke: `Skill("media-management:archive-media", args="wav $ALBUM_ARTIST $ALBUM $WAV_EXTRACTION_FOLDER")`
- Use the same `$ALBUM_ARTIST` as Step 9 so the mp3/ and wav/ trees under `to_nas/` mirror each other
- WAVs NEVER go through Apple Music import

**Step 13: Cleanup**
→ Invoke: `Skill("media-management:cleanup", args="\"$RELEASE_NAME\" --zip \"$MP3_SOURCE_PATH\" --zip \"$WAV_SOURCE_PATH\" --folder \"$EXTRACTION_FOLDER\" --folder \"$WAV_EXTRACTION_FOLDER\"")`
- Pass the exact paths tracked since Steps 1/2/11 rather than relying on cleanup's release-name
  matching — a vendor ZIP's filename frequently doesn't match the clean release name used for
  the extraction folder (e.g. a Various Artists compilation ZIP named after all contributing
  artists), which name matching alone would miss on one side or the other
- Moves original ZIPs/loose audio files to processed/, cleans extraction folders
- Cleanup asks before it moves or deletes anything, like every other destructive step

### Batch Processing Multiple Releases

**Trigger:** the user asks to process several releases in one go and explicitly asks for fewer
interruptions — e.g. "process all of them, let me check once at the end" — rather than the
default one-release-at-a-time flow with a confirmation per release.

**What changes:**
- Run Steps 1–6 for every release without stopping at Step 4's per-release confirmation. For
  genre specifically, make your best inference from track titles/style/label context instead of
  presenting a numbered list per release — note this is a judgment call, not free license: only
  do it under this explicit trigger, and say so in the summary (see below).
- After all releases have been imported (Step 7) and archived (Steps 9–13), present **one**
  consolidated table covering every release: tracks, chosen genre, album type, Apple Music
  destination, NAS archive status. Mark inferred genres clearly (e.g. "my pick — flag if wrong")
  so the user knows which fields to double check.
- This single table **is** the Step 4/8 confirmation for a batch run — it satisfies the mandatory
  checkpoint rule by covering all releases at once instead of skipping it.

**If the user corrects a genre (or other tag) after this point:** the files are usually already
archived to NAS. Since `archive-media`'s MP3 mode re-copies from Apple Music (which captures
whatever the user just edited there), simply re-run Step 9 for the affected release to sync the
correction to NAS — no need to redo the whole pipeline. WAV archives don't carry genre and don't
need re-syncing for a genre-only correction.
