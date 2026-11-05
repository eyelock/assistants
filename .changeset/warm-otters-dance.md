---
"@eyelock-assistants/media-management": minor
---

Fix two real bugs surfaced while processing a Various Artists pre-order release, and document a batch-processing pattern for multi-release runs.

`archive-media`'s MP3 workflow assumed the NAS/Apple-Music path uses the track Artist
(`$LIBRARY_STORAGE/$ARTIST/$ALBUM`), but Apple Music actually files an album under its Album
Artist tag — "Various Artists" for a compilation, the primary artist for a collaboration — falling
back to the track Artist only when Album Artist is cleared (the single-artist case). Archiving a
compilation's MP3s failed with "source folder not found" until the correct folder was found by
hand. `archive-media/SKILL.md` now documents the Album Artist fallback rule, and `process-album`
threads a tracked `$ALBUM_ARTIST` variable through Steps 6, 9, and 12 instead of reusing `$ARTIST`.

`cleanup`'s `find-release-artifacts.sh`/`cleanup-release.sh` matched ZIPs and extraction folders
by globbing a single `release_name` string against both. That breaks whenever a vendor ZIP's
filename diverges from the clean extraction folder name — e.g. a 10-artist compilation ZIP
(`lovetrip- monovan- ... - keep it deep (pre-order).zip`) extracted into a folder simply named
`keep it deep`: matching on the clean name found the folder but missed the ZIP. Both scripts now
accept repeatable `--zip <path>`/`--folder <path>` flags for exact paths, merged and deduplicated
with any glob matches; `release_name` may be `""` when only explicit paths are given. `process-album`'s
Step 13 now passes the exact paths it already tracked since Steps 1/2/11 instead of re-deriving
them from a name.

`process-album/SKILL.md` gains a "Batch Processing Multiple Releases" section (and a documented
exception in `references/safety-rules.md`) for when a user explicitly asks to process several
releases with a single confirmation at the end: Steps 4/8 collapse into one consolidated table
across all releases, genre may be an inferred best guess (clearly flagged as such) rather than a
per-release numbered choice, and a post-hoc genre correction just means re-running the MP3 archive
step for that release rather than redoing the whole pipeline.
