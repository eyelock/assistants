# Contributing

## Tech stack

This is a Claude Code plugin built entirely with bash scripts and markdown. There is no build step, no package manager, and no compiled artifacts.

| Component | Technology | Why |
|-----------|-----------|-----|
| Skills | Markdown (SKILL.md with YAML frontmatter) | Claude Code plugin format — skills are cached prompts |
| Scripts | Bash | ffmpeg/ffprobe are CLI tools; wrapping in Node.js adds no value |
| Audio processing | ffmpeg + ffprobe (Homebrew) | Industry-standard, handles all formats |
| Genre extraction | osascript + mdfind | Native macOS, no dependencies |
| Metadata I/O | ffprobe (read) + ffmpeg (write) | Correct ID3v2 frame mapping, `-map_metadata 0` preserves tags |
| Testing | Bash test scripts + ffmpeg-generated fixtures | No test framework needed |
| Linting | shellcheck | Standard for bash |
| Validation | Makefile `validate` target | Checks plugin structure, frontmatter, permissions |

### Why bash instead of Node.js

The archived predecessor used Node.js with `node-id3` and child process calls to ffmpeg. The rewrite to bash eliminated:

- `node_modules` and version drift
- Incorrect ID3 mapping (`node-id3` maps `performerInfo` to TPE3/conductor, not TPE2/album artist)
- Fake silence detection (random offsets instead of real `silencedetect`)
- A runtime dependency beyond what macOS + Homebrew already provides

### Why a plugin instead of an MCP server

This is a personal macOS workflow tied to Apple Music and local NAS. The plugin model gives us:

- Skills as cached prompts (loaded on demand, not on every tool call)
- Inline user confirmation (skills run in the main conversation)
- Subagents on Haiku for cheap analysis work
- No server infrastructure to manage

Portability to other AI clients is not a priority.

## Project structure

```
media-management/
├── harness.json                   # Harness manifest (name, version, author)
├── .claude/
│   ├── CLAUDE.md                  # Project instructions, config, safety rules
│   └── settings.json              # Permissions, env vars, announcements
├── config.json                    # Fallback config (lowest priority)
├── hooks/
│   ├── hooks.json                 # Hook registration (PreToolUse on Bash)
│   └── validate-bash-command.sh   # Safety hook — blocks dangerous commands
├── skills/
│   ├── process-album/             # Main orchestrator — delegates to all others
│   │   ├── SKILL.md
│   │   └── references/            # Album types, safety rules
│   ├── select-release/            # Find ZIP pairs in Downloads
│   ├── manage-metadata/           # Inspect + update MP3 tags
│   │   └── scripts/               # 7 bash scripts for metadata operations
│   ├── split-long-tracks/         # Split >78min tracks at silence
│   │   └── scripts/
│   ├── import-to-apple-music/     # Copy to Apple Music auto-import
│   ├── archive-media/             # Stage to NAS storage
│   │   └── scripts/
│   └── cleanup/                   # Archive ZIPs, remove temp folders
├── agents/
│   ├── media-analyst.md           # File analysis subagent (Haiku)
│   └── metadata-checker.md        # Metadata consistency subagent (Haiku)
├── tests/
│   ├── run-tests.sh               # Test runner
│   ├── fixtures/                  # Generated test audio (gitignored)
│   ├── scripts/                   # Unit tests for each script
│   ├── hooks/                     # Hook tests
│   └── evals/                     # Manual skill evaluation scenarios
├── Makefile
├── README.md
└── CONTRIBUTING.md
```

### Script ownership

Each script lives in exactly one skill's `scripts/` directory. No duplication.

| Script | Owning skill | Purpose |
|--------|-------------|---------|
| `inspect-metadata.sh` | manage-metadata | Read metadata for all MP3s in a folder |
| `update-track-count.sh` | manage-metadata | Set track X/total sequentially |
| `update-genre.sh` | manage-metadata | Set genre on all MP3s |
| `clear-album-artist.sh` | manage-metadata | Remove Album Artist (TPE2) |
| `set-album-artist.sh` | manage-metadata | Set Album Artist (TPE2) |
| `set-compilation.sh` | manage-metadata | Set compilation flag + Album Artist |
| `extract-apple-music-genres.sh` | manage-metadata | Get genres from Apple Music library |
| `split-long-tracks.sh` | split-long-tracks | Split at silence using silencedetect |
| `rename-wav-files.sh` | archive-media | Rename WAVs to "01 Title.wav" format |

### Design rules

- `process-album` is a **skill** (not a subagent) because it needs interactive user confirmation at two mandatory checkpoints. Subagents run in isolation.
- `process-album` is a **pure orchestrator** — it has no scripts and delegates to other skills.
- Skills without scripts use standard shell commands (`unzip`, `cp`, `mv`, `mkdir`) via their SKILL.md instructions.

## Development setup

### Prerequisites

```bash
brew install ffmpeg    # Audio processing
brew install jq        # JSON handling in scripts
brew install shellcheck # Linting
```

### Available make targets

```
make help           # Show all targets
make check          # Lint + validate + test (run before committing)
make lint           # Shellcheck all scripts
make validate       # Check plugin structure and frontmatter
make test           # Run full test suite
make test-scripts   # Script tests only
make test-hooks     # Hook tests only
make fixtures       # Generate test audio fixtures
make install        # Symlink plugin for local use
make uninstall      # Remove plugin symlink
make clean          # Remove fixtures + uninstall
```

### Running tests

```bash
make check
```

This runs shellcheck, validates the plugin structure, generates test fixtures (short audio files via ffmpeg), and runs all 10 test scripts. Tests use temp directories and clean up after themselves.

Test fixtures are generated audio files (silent MP3s/WAVs with known metadata). They are gitignored and regenerated on each test run if missing.

### Script conventions

Every script follows these rules:

- **No interactive prompts** — all input via arguments
- **`--help` flag** — description, usage, examples
- **JSON to stdout** — structured output for Claude to parse
- **Diagnostics to stderr** — warnings and progress info
- **Exit codes** — 0 success, 1 bad args, 2 file not found, 3 ffmpeg error
- **Idempotent** — safe to re-run without corrupting files
- **macOS compatible** — no bash 4+ features (`mapfile`), no GNU-only flags (`grep -P`, `head -n -1`), no `timeout` command

### SKILL.md conventions

Following the [Agent Skills Specification](https://agentskills.io/specification):

- YAML frontmatter with `name`, `description`, `compatibility`, `allowed-tools`, `metadata`
- `name` must match the directory name (validated by `make validate`)
- `description` in third person, includes trigger keywords
- Body under 500 lines — detailed rules go in `references/`
- Script invocations use relative paths from the skill directory
- Cross-skill delegation says "delegate to X skill", not "run X's script"

### Subagent conventions

Following [Claude Code Sub-agents docs](https://code.claude.com/docs/en/sub-agents):

- YAML frontmatter with `name`, `description`, `model`, `tools`
- `model: haiku` for cost-efficient analysis
- Markdown body is the system prompt
- Read-only — subagents never modify files

### Adding a new skill

1. Create `skills/your-skill/SKILL.md` with frontmatter
2. Add scripts (if any) to `skills/your-skill/scripts/`
3. Make scripts executable: `chmod +x skills/your-skill/scripts/*.sh`
4. Add tests to `tests/scripts/test-your-script.sh`
5. Run `make check` to validate everything

### Adding a new script

1. Place it in the owning skill's `scripts/` directory
2. Include a `--help` flag, JSON output, meaningful exit codes
3. Use `while IFS= read -r f; do ... done < <(find ...)` for file collection (not `mapfile`)
4. Use `[[:space:]]` instead of `\s` in grep patterns (BSD compatibility)
5. Use `${var%%.*}` instead of `sed 's/\..*$//'` for float truncation
6. Add a test in `tests/scripts/test-your-script.sh`
7. Run `make check`

### The safety hook

`hooks/validate-bash-command.sh` runs before every Bash tool call. It blocks:

- Extracting archives directly to Downloads root
- `rm -rf` on critical directories (Downloads, Music, archive root)
- Commands referencing credential paths (`.ssh/`, `.aws/`, etc.)

The hook handles command chaining (`&&`, `||`, `;`) — patterns match anywhere in the command, not just at the end. Test it with `make test-hooks`.

### Permissions model

`.claude/settings.json` defines what commands are auto-approved. The principle is:

- **Allow** all commands the skills actually need (ffmpeg, ffprobe, unzip, cp, mv, etc.)
- **Deny** reads of sensitive files (.ssh, .aws, .env, private keys)
- **Scope narrowly** where possible (e.g., `rm` is scoped to test fixtures and Downloads subfolders)

Deny rules take precedence over allow rules.
