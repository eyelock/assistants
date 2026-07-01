---
"@eyelock-assistants/media-management": patch
---

Fix filename handling for releases with accented characters and track numbers of 08 or higher. `rename-wav-files.sh` now forces base-10 track-number padding (previously `08`/`09` were parsed as invalid octal, aborting the rename); `extract-zip.sh` extracts with `ditto` on macOS to handle non-UTF-8 filenames that `unzip` rejects on APFS; and `inspect-zip.sh` sets a byte-safe locale so the release classifier no longer silently drops releases whose track names contain non-ASCII characters.
