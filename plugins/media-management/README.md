# Media Management

A Claude Code plugin for getting music into Apple Music and onto a NAS: downloaded purchases (MP3/WAV ZIP pairs from your Downloads folder) and audio CDs (ripped securely and checked against AccurateRip). It manages metadata, imports MP3s to Apple Music, stages MP3s and lossless WAVs to NAS storage, and repairs albums Apple Music split per disc or half imported.

## What it does

When you buy music online (Bandcamp, Beatport, etc.), you typically get two ZIP files — one with MP3s and one with WAVs. This plugin handles the entire workflow:

1. Finds and identifies ZIP pairs in your Downloads folder
2. Extracts archives into organized subfolders
3. Inspects and updates MP3 metadata (genre, artist, album, track numbers, compilation flag)
4. Imports MP3s to Apple Music
5. Stages both MP3 and WAV files to your NAS/archive storage
6. Cleans up Downloads when done

The plugin asks for your confirmation at key checkpoints — it won't auto-select genres or proceed without you verifying the metadata and import results.

## Audio CDs

`/media-management:rip-cd` replaces Apple Music's own CD import, which names tracks from its own lookup (often repeating the release name on every title), files each disc of a set as a separate album, guesses artwork, and keeps no lossless copy. Instead it:

1. Identifies the disc locally from its table of contents (MusicBrainz disc ID and AccurateRip ID), then looks it up on MusicBrainz, offering every edition the disc belongs to (a box set and a standalone set, say)
2. Asks the usual questions one at a time: edition, titles (MusicBrainz's or the disc's own, cleaned of repeated suffixes; plain punctuation), genre (never picked for you)
3. Rips securely with `cd-paranoia` and checks every track against AccurateRip (with your drive's read offset), so the WAV backup is bit-perfect
4. Makes MP3 320s (tagged, cover from the Cover Art Archive embedded, MusicBrainz IDs) and WAVs from that one verified rip
5. Imports the MP3s to Apple Music, waits for you to check, then stages MP3s and WAVs (with the release record and cover) to the NAS

Discs of a set are numbered among the CDs only and share one album; a later disc, ripped another day, is recognized from the record on the NAS and asks nothing. Work in progress lives in a temporary folder (`$TMPDIR/media-management` by default), never in Downloads.

## Repairing imports

`/media-management:audit-release` checks an album against everything a finished import should be: one album in Apple Music, Album Artist set, consistent disc tags, clean titles, a real embedded cover, MusicBrainz release ID, MP3 320, MP3s and WAVs on the NAS, nothing left behind. It finds albums split across several entries ("M" and "M [Disc 2]"), merges them in place through Apple Music (no re-import), strips repeated suffixes, replaces guessed artwork, and can replace a bad import by re-ripping. Every repair is planned and shown first, and can be undone.

## Requirements

- macOS with Apple Music
- [Claude Code](https://claude.com/claude-code) >= 1.0.33
- ffmpeg and ffprobe: `brew install ffmpeg`
- For CDs: an optical drive, `cd-paranoia` (`brew install libcdio-paranoia`), python3 and curl. `rip-cd` checks these and tells you what to install

## Installation

Clone the repository and install the plugin:

```bash
git clone https://github.com/eyelock/media-management.git
cd media-management
make install
```

This creates a symlink in `~/.claude/plugins/repos/` so Claude Code picks up the plugin automatically.

## Configuration

The plugin needs to know where your files are. Paths are resolved in this order:

1. **Environment variables** (highest priority)
2. **config.json**, a per-user file at `$MEDIA_MGMT_CONFIG_PATH`

No default paths ship with the plugin.

Run `/media-management:setup` to check which of these are missing and get help filling them in — it can write `config.json` for you.

### Environment variables

Set any of these in your shell profile to override defaults:

| Variable | Description | Default |
|----------|-------------|---------|
| `MEDIA_MGMT_DOWNLOADS` | Where your ZIPs land | — (e.g. `~/Downloads`) |
| `MEDIA_MGMT_LIBRARY_IMPORT` | Apple Music auto-import folder | — (e.g. `~/Music/Music/Media.localized/Automatically Add to Music.localized`) |
| `MEDIA_MGMT_LIBRARY_STORAGE` | Apple Music library location | — (e.g. `~/Music/Music/Media.localized/Music`) |
| `MEDIA_MGMT_ARCHIVE_WORKDIR` | NAS staging directory | — (any local folder that syncs to the NAS) |
| `MEDIA_MGMT_PROCESSED` | Where cleanup moves finished ZIPs | `<downloads>/processed` (optional) |
| `MEDIA_MGMT_CD_READ_OFFSET` | Your optical drive's read offset in samples, for the AccurateRip check | — (e.g. `6` for a TSSTcorp SE-506; optional) |
| `MEDIA_MGMT_WORK_DIR` | Where temporary work (rips, encodes, plans) goes | `$TMPDIR/media-management` (optional) |
| `MEDIA_MGMT_REKORDBOX_MCP_PATH` | Local checkout of the [rekordbox-mcp](https://github.com/davehenke/rekordbox-mcp) server | — (no default; required for the `rekordbox-database` MCP server) |
| `MEDIA_MGMT_CONFIG_PATH` | Location of the fallback config file | `~/.config/media-management/config.json` |

### config.json

`config.json` is **not** shipped in this repo — it's a per-user file, since it holds machine-specific paths. `/media-management:setup` creates it for you at `$MEDIA_MGMT_CONFIG_PATH` (or its default location) if it doesn't already exist.

### Finding your Apple Music import path

The auto-import folder location varies by macOS version. Find yours with:

```bash
find ~ -name "Automatically Add to Music.localized" -type d 2>/dev/null
```

## Usage

### Process a full album

The main entry point. Handles everything from ZIP extraction to cleanup:

```
/media-management:process-album
```

Or specify a release directly:

```
/media-management:process-album Artist - Album
```

### Individual skills

Each step of the workflow is also available as a standalone skill:

| Skill | What it does |
|-------|-------------|
| `/media-management:setup` | Check required paths are configured; help fill in any that are missing |
| `/media-management:select-release` | Find and identify ZIP pairs in Downloads |
| `/media-management:manage-metadata` | Inspect or update MP3 metadata |
| `/media-management:split-long-tracks` | Split tracks exceeding 78 minutes at quiet points |
| `/media-management:import-to-apple-music` | Copy files to Apple Music auto-import |
| `/media-management:archive-media` | Stage files to NAS storage |
| `/media-management:cleanup` | Archive ZIPs and remove temp folders |
| `/media-management:rip-cd` | Rip an audio CD: identify, ask, rip securely, verify, encode MP3 + WAV, import, stage |
| `/media-management:audit-release` | Check an album in Apple Music and the NAS; repair splits, titles and artwork; replace a bad import |
| `/media-management:reclaim-space` | Offload cloud-backed Apple Music downloads to free local disk |

### Inspect metadata without changing anything

```
/media-management:manage-metadata inspect ~/Downloads/Artist - Album
```

### Update metadata

```
/media-management:manage-metadata update ~/Downloads/Artist - Album
```

## How it handles album types

The plugin detects and handles three album types based on artist analysis:

- **Single Artist** — All tracks by the same artist. Clears the Album Artist field.
- **Collaboration** — Two artists across tracks. Sets Album Artist to the primary artist.
- **Compilation** — Three or more artists. Sets Album Artist to "Various Artists" and marks as compilation.

You'll always be asked to confirm the classification before any changes are applied.

## Safety

The plugin enforces several safety rules:

- Archives are always extracted into named subfolders, never directly into Downloads
- You must confirm all metadata before import and verify the Apple Music import before archival
- Genre is never auto-selected — you always choose from your existing library genres or type a custom one
- MP3s go to Apple Music; WAVs are archived directly (no duplicates)
- A CD rip is checked against AccurateRip before anything is imported; a mismatch stops the run
- Repairs to Apple Music are planned and shown before they run, keep their plan as the undo, and removing old tracks moves their files to the Trash
- Original files are preserved until the entire workflow completes
- A safety hook blocks dangerous commands (deleting critical directories, accessing credentials). It auto-approves only single calls to the plugin's own scripts; every other command goes through Claude Code's normal permission prompts

## Uninstalling

```bash
make uninstall
```

This removes the symlink from `~/.claude/plugins/repos/`. Your music files and Apple Music library are not affected.
