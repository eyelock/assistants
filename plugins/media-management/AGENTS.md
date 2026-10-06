# Media Management Plugin

Process downloaded music purchases (MP3/WAV ZIP pairs) into Apple Music and NAS storage.

## Prerequisites

- macOS with Apple Music app
- `brew install ffmpeg` (provides ffmpeg and ffprobe)
- `unzip` (ships with macOS)

## Configuration

### Path resolution

Skills resolve paths in this order:
1. Environment variables (if set)
2. config.json at $MEDIA_MGMT_CONFIG_PATH, default `~/.config/media-management/config.json`

No default paths ship with the plugin. If neither source resolves a required
path, run the `/setup` skill — it walks through each path and writes
config.json for you. Typical values:

- Downloads: `~/Downloads` — where purchased ZIPs land
- Apple Music import: the library's "Automatically Add to Music.localized" folder
- Apple Music library: `~/Music`
- Archive/NAS staging: a local staging folder that syncs to your NAS

### Environment variable overrides

Set any of these to override the defaults above:
- MEDIA_MGMT_DOWNLOADS
- MEDIA_MGMT_LIBRARY_IMPORT
- MEDIA_MGMT_LIBRARY_STORAGE
- MEDIA_MGMT_ARCHIVE_WORKDIR
- MEDIA_MGMT_REKORDBOX_MCP_PATH
- MEDIA_MGMT_CONFIG_PATH (path to the config.json fallback file itself; default `~/.config/media-management/config.json`)

## Safety Rules

1. **Never extract to Downloads root** — always extract into a named subfolder
2. **Mandatory user confirmation** for all metadata before import (Step 4) and after Apple Music import (Step 8)
3. **Never auto-select genre** — always present options and ask
4. **MP3s to Apple Music, WAVs skip Apple Music** — prevents duplicates
5. **Process MP3s first, then WAVs separately**
6. **Never trust filename suffixes** for format detection — use `unzip -l` and file size
7. **Preserve originals** until entire workflow is complete

## Album Type Classification

- **Single Artist**: All tracks same artist. Clear Album Artist field, no compilation flag.
- **Collaboration**: Two artists across tracks. Set Album Artist to primary artist.
- **Compilation**: 3+ different artists. Set Album Artist to "Various Artists", set compilation flag = true. Each track keeps its own Artist.

## File Splitting Rules

- Splits replace the original file
- A track alone in its folder becomes a mini-album: "01 Title.mp3", "02 Title.mp3", tracks 1/N
- A track inside an album keeps its place: "03 Title 1.mp3", "03 Title 2.mp3", keeping its track number
- No "Part X" in filenames or titles
- After splitting, re-run update-track-count.sh, which renumbers the whole folder in album order (existing track number, then filename)
