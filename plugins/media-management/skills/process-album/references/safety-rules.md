# Safety Rules

These rules are non-negotiable. Never bypass them.

## Extraction

- **NEVER extract to Downloads root** — always create a named subfolder first
- If extraction fails, ask the user to extract manually via Finder

## Format Detection

- **NEVER trust filename suffixes** for format detection
- Always inspect archive contents with `unzip -l`
- Use file size and listed extensions to classify MP3 vs WAV

## User Confirmation

- **Step 4 (metadata):** MANDATORY stop. Present all metadata fields and get explicit user confirmation before proceeding
- **Step 8 (Apple Music):** MANDATORY stop. User must check Apple Music and confirm the import is correct
- **Genre selection:** NEVER auto-select a genre. Always present options and let the user choose

## Processing Order

- Process MP3s first, then WAVs separately
- MP3s go through Apple Music import; WAVs NEVER go through Apple Music (prevents duplicates)

## File Preservation

- Preserve all original files (ZIPs and extracted content) until the entire workflow is complete
- Only the cleanup skill at the final step moves/deletes originals

## File Splitting

- Split parts replace the original file
- Name splits sequentially (01, 02, ...) — no "Part X" in filenames or titles
- After splitting, re-run update-track-count.sh to renumber the entire folder
