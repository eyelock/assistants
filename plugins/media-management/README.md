# Media Management

A Claude Code plugin for processing downloaded music purchases. Takes MP3/WAV ZIP pairs from your Downloads folder, manages metadata, imports to Apple Music, and stages files to NAS storage.

## What it does

When you buy music online (Bandcamp, Beatport, etc.), you typically get two ZIP files — one with MP3s and one with WAVs. This plugin handles the entire workflow:

1. Finds and identifies ZIP pairs in your Downloads folder
2. Extracts archives into organized subfolders
3. Inspects and updates MP3 metadata (genre, artist, album, track numbers, compilation flag)
4. Imports MP3s to Apple Music
5. Stages both MP3 and WAV files to your NAS/archive storage
6. Cleans up Downloads when done

The plugin asks for your confirmation at key checkpoints — it won't auto-select genres or proceed without you verifying the metadata and import results.

## Requirements

- macOS with Apple Music
- [Claude Code](https://claude.com/claude-code) >= 1.0.33
- ffmpeg and ffprobe: `brew install ffmpeg`

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
2. **CLAUDE.md defaults** (edit `.claude/CLAUDE.md` for your setup)
3. **config.json** at the project root (lowest priority)

### Environment variables

Set any of these in your shell profile to override defaults:

| Variable | Description | Default |
|----------|-------------|---------|
| `MEDIA_MGMT_DOWNLOADS` | Where your ZIPs land | `~/Downloads` |
| `MEDIA_MGMT_LIBRARY_IMPORT` | Apple Music auto-import folder | `~/Automatically Add to Music.localized` |
| `MEDIA_MGMT_LIBRARY_STORAGE` | Apple Music library location | `~/Music` |
| `MEDIA_MGMT_ARCHIVE_WORKDIR` | NAS staging directory | `~/Storage/Music` |

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
| `/media-management:select-release` | Find and identify ZIP pairs in Downloads |
| `/media-management:manage-metadata` | Inspect or update MP3 metadata |
| `/media-management:split-long-tracks` | Split tracks exceeding 78 minutes at quiet points |
| `/media-management:import-to-apple-music` | Copy files to Apple Music auto-import |
| `/media-management:archive-media` | Stage files to NAS storage |
| `/media-management:cleanup` | Archive ZIPs and remove temp folders |

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
- Original files are preserved until the entire workflow completes
- A safety hook blocks dangerous commands (deleting critical directories, accessing credentials)

## Uninstalling

```bash
make uninstall
```

This removes the symlink from `~/.claude/plugins/repos/`. Your music files and Apple Music library are not affected.
