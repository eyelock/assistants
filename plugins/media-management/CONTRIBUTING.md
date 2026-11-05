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
├── .claude-plugin/plugin.json     # Plugin manifest (name, version, author)
├── AGENTS.md                      # Instructions, config, safety rules
├── (no config.json here — per-user file at ~/.config/media-management/config.json)
├── hooks/
│   ├── hooks.json                 # Hook registration (SessionStart, PreToolUse)
│   ├── validate-bash-command.sh   # Safety hook — blocks dangerous commands
│   ├── gate-config-required-skills.sh  # Blocks path-dependent scripts until configured
│   ├── check-config-session.sh    # Nudges toward /setup when config is missing
│   └── auto-approve-tools.sh      # Approves reads inside the configured folders
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
│   ├── cleanup/                   # Archive ZIPs, remove temp folders
│   └── */evals/                   # Each skill's output evals and trigger queries
├── agents/
│   ├── media-analyst.md           # File analysis subagent (Haiku)
│   └── metadata-checker.md        # Metadata consistency subagent (Haiku)
├── tests/
│   ├── run-tests.sh               # Test runner
│   ├── fixtures/                  # Generated test audio (gitignored)
│   ├── scripts/                   # Unit tests for each script
│   └── hooks/                     # Hook tests
├── evals/files/                   # Eval sandbox builders shared by every skill's evals
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
make evals          # Run every skill's evals (sandboxed; costs money)
make install        # Symlink plugin for local use
make uninstall      # Remove plugin symlink
make clean          # Remove fixtures + uninstall
```

### Running tests

```bash
make check
```

This runs shellcheck, validates the plugin structure, generates test fixtures (short audio files via ffmpeg), and runs every test script. Tests use temp directories, clean up after themselves, and never read your real config (`run-tests.sh` clears the `MEDIA_MGMT_*` variables).

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

- YAML frontmatter with `name`, `description`, `allowed-tools`. No `metadata` key: Claude Code's
  plugin loader demotes a skill that has one to a stub that never fires (`ynd lint` checks this)
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
5. Add evals: `skills/your-skill/evals/evals.json` (sandboxed cases, see below) and `eval_queries.json`
6. Run `make check` to validate everything

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

The hooks run in every Claude Code session once the plugin is installed, not only during media work, so they approve as little as possible:

- `validate-bash-command.sh` auto-approves a single call to one of the plugin's own scripts (no chaining, pipes, redirects or command substitution). Every other command goes through the normal permission flow.
- `auto-approve-tools.sh` approves this plugin's own skills, and reads inside the configured folders.
- Each skill's `allowed-tools` grants what it needs while it runs.

### Evals

Every skill has `evals/evals.json` (output evals) and `evals/eval_queries.json` (trigger evals), run by the repository's `scripts/skill-evals.mjs` (`make evals` here, or `make eval P=plugins/media-management` at the root). Each output case is a shell sandbox: its setup script in `evals/files/` builds a world in the run's directory with `sandbox.sh` — Downloads, the Apple Music auto-import folder and library, a NAS staging folder, real tagged audio made by ffmpeg, and a config.json the session points `MEDIA_MGMT_CONFIG_PATH` at — and `osascript` is a stub (`osascript-stub.sh`) standing in for the Music app. `evidence.sh` then shows the judge every file the run added, removed or changed, and the tags of every MP3.
