# @eyelock-assistants/media-management

## 0.4.0

### Minor Changes

- [#63](https://github.com/eyelock/assistants/pull/63) [`5aa4314`](https://github.com/eyelock/assistants/commit/5aa431458249fa57f528b1e449b9d8e3af9a9aa9) Thanks [@eyelock](https://github.com/eyelock)! - Rip audio CDs and repair bad imports. The new `rip-cd` skill identifies a disc on MusicBrainz from its table of contents, rips it securely with cd-paranoia, verifies it against AccurateRip, and makes tagged MP3 320s (for Apple Music) and WAVs (for the NAS) from the one verified rip, with every disc of a set in one album. The new `audit-release` skill checks an album against a finished import, finds albums Apple Music split per disc, and merges, retitles, re-covers or replaces them in place, with a plan shown first and an undo. Also: temporary work goes to `$TMPDIR/media-management`, multi-disc WAV archives verify correctly and keep `1-01` names, `import-mp3s.sh --wait` confirms Apple Music picked files up, and setup reports `cd_read_offset` and `work_dir` as optional.

- [#48](https://github.com/eyelock/assistants/pull/48) [`1673d5a`](https://github.com/eyelock/assistants/commit/1673d5a5527afac0d011dc7be1ea5b30fbe2cec6) Thanks [@eyelock](https://github.com/eyelock)! - Add sandboxed evals for the media-management skills and fix what they exposed: paths come from check-config.sh, the approval hooks are much narrower, cleanup no longer matches other releases, duplicate downloads are reported, track renumbering and splitting keep album order, and scripts use $TMPDIR and work on bash 3.2.

- [#43](https://github.com/eyelock/assistants/pull/43) [`a4968ff`](https://github.com/eyelock/assistants/commit/a4968ff7363ae68709cca8bce1c2fbb44677f2fe) Thanks [@eyelock](https://github.com/eyelock)! - Fix two real bugs surfaced while processing a Various Artists pre-order release, and document a batch-processing pattern for multi-release runs.

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

## 0.3.0

### Minor Changes

- [#24](https://github.com/eyelock/assistants/pull/24) [`8487ec6`](https://github.com/eyelock/assistants/commit/8487ec6fa12804439e7abcad9a9e66860074d72c) Thanks [@eyelock](https://github.com/eyelock)! - Add support for single-track purchases that download as loose MP3/WAV files with no ZIP wrapper. `find-releases.sh` now scans Downloads for loose audio files alongside ZIPs and pairs them the same way (`Track.mp3` + `Track.wav` → one release), via a new `inspect-audio-file.sh`; release entries now report `mp3_source`/`wav_source` with a `source_type` of `"zip"` or `"file"` (renamed from `mp3_zip`/`wav_zip`, which assumed a ZIP). `process-album` gained a `copy-file.sh` script so it can place a loose file into the working folder instead of extracting a ZIP. `cleanup`'s `find-release-artifacts.sh`/`cleanup-release.sh` now also find and archive loose audio files to `processed/`.

  Also fixed a latent bug in `find-release-artifacts.sh`: its glob-matching subshells ran under `set -e`, so a non-matching `ls`/`[[ -d ]]` glob (e.g. no `-2` suffix ZIP, or no separate `-wav` extraction folder — the common case for a solo release) silently aborted the subshell and dropped every pattern checked after it. Every glob attempt now ends in `|| true`.

## 0.2.0

### Minor Changes

- [#23](https://github.com/eyelock/assistants/pull/23) [`80391dd`](https://github.com/eyelock/assistants/commit/80391dd26085f530f3a87edac52f1a35f397d798) Thanks [@eyelock](https://github.com/eyelock)! - Add rekordbox-mcp integration and a `/setup` onboarding skill; relocate `config.json` out of the repo. The `rekordbox-database` MCP server (from davehenke/rekordbox-mcp, path via `MEDIA_MGMT_REKORDBOX_MCP_PATH`) is declared in `.mcp.json` with its tools auto-approved via hooks. `config.json` is no longer shipped in the repo — it's a per-user file at `$MEDIA_MGMT_CONFIG_PATH` (default `~/.config/media-management/config.json`); existing installs relying on the old project-root `config.json` should run `/media-management:setup` or set the `MEDIA_MGMT_*` env vars directly. `/setup` checks all required paths, walks the user through filling in anything missing, and writes `config.json`; a `SessionStart` hook nudges toward it when config is incomplete, and a `PreToolUse` hook blocks the config-dependent skills (`process-album`, `select-release`, `cleanup`, `manage-metadata`, `import-to-apple-music`, `archive-media`) until it's fixed. Also fixes a stale hardcoded script path in `select-release`, and adds `evals/` (output-quality test cases, trigger-eval queries, and a fixture generator) for every skill per the agentskills.io skill-authoring guides — tightening three skill descriptions based on real trigger-eval results (97/101 → 101/101 pass rate, zero false positives).

- [#24](https://github.com/eyelock/assistants/pull/24) [`f48e61d`](https://github.com/eyelock/assistants/commit/f48e61d3b2fcfb61e878587dac6fc9e384f61399) Thanks [@eyelock](https://github.com/eyelock)! - Add support for single-track purchases that download as loose MP3/WAV files with no ZIP wrapper. `find-releases.sh` now scans Downloads for loose audio files alongside ZIPs and pairs them the same way (`Track.mp3` + `Track.wav` → one release), via a new `inspect-audio-file.sh`; release entries now report `mp3_source`/`wav_source` with a `source_type` of `"zip"` or `"file"` (renamed from `mp3_zip`/`wav_zip`, which assumed a ZIP). `process-album` gained a `copy-file.sh` script so it can place a loose file into the working folder instead of extracting a ZIP. `cleanup`'s `find-release-artifacts.sh`/`cleanup-release.sh` now also find and archive loose audio files to `processed/`.

  Also fixed a latent bug in `find-release-artifacts.sh`: its glob-matching subshells ran under `set -e`, so a non-matching `ls`/`[[ -d ]]` glob (e.g. no `-2` suffix ZIP, or no separate `-wav` extraction folder — the common case for a solo release) silently aborted the subshell and dropped every pattern checked after it. Every glob attempt now ends in `|| true`.

- [#23](https://github.com/eyelock/assistants/pull/23) [`80391dd`](https://github.com/eyelock/assistants/commit/80391dd26085f530f3a87edac52f1a35f397d798) Thanks [@eyelock](https://github.com/eyelock)! - Add `reclaim-space` skill: reclaim local disk by offloading cloud-backed Apple Music downloads. `audit-library.sh` reports the iCloud-status histogram (cloud-safe vs Ineligible) and the protected "keep" folder's playlists; `build-offload-playlist.sh` creates a snapshot playlist of tracks that are safe to Remove Download — excluding the keep folder, a Grouping prefix, and local-only Kinds (WAV). Includes a reference recipe for the auto-updating Smart Playlist equivalent. Non-destructive: removing downloads stays a deliberate manual step.

### Patch Changes

- [#23](https://github.com/eyelock/assistants/pull/23) [`80391dd`](https://github.com/eyelock/assistants/commit/80391dd26085f530f3a87edac52f1a35f397d798) Thanks [@eyelock](https://github.com/eyelock)! - Fix filename handling for releases with accented characters and track numbers of 08 or higher. `rename-wav-files.sh` now forces base-10 track-number padding (previously `08`/`09` were parsed as invalid octal, aborting the rename); `extract-zip.sh` extracts with `ditto` on macOS to handle non-UTF-8 filenames that `unzip` rejects on APFS; and `inspect-zip.sh` sets a byte-safe locale so the release classifier no longer silently drops releases whose track names contain non-ASCII characters.

- [#24](https://github.com/eyelock/assistants/pull/24) [`f48e61d`](https://github.com/eyelock/assistants/commit/f48e61d3b2fcfb61e878587dac6fc9e384f61399) Thanks [@eyelock](https://github.com/eyelock)! - Remove machine-specific absolute paths from shipped plugin files. `AGENTS.md` no longer lists a specific user's directories as "default paths" — path resolution is now env vars then `config.json` only, with `/setup` as the onboarding route when neither resolves. `.codex/config.toml` uses `/Users/YOUR_USERNAME/...` placeholders in its sandbox writable-roots and env examples, and the `/setup` skill's example output table uses `~/Downloads`. Previously these files carried the plugin author's home-directory paths, which other installs could silently fall back to.
