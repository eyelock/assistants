#!/usr/bin/env bash
# Run a command with every MEDIA_MGMT_* env var unset, so skill evals against
# tests/fixtures/eval-sandbox can never accidentally read the user's real
# config and leak test fixtures into real Downloads/Apple Music/NAS paths.
#
# Usage: run-isolated.sh <command> [args...]
set -euo pipefail

if [[ "${1:-}" == "--help" || $# -lt 1 ]]; then
  cat <<'HELP'
Usage: run-isolated.sh <command> [args...]

Runs <command> with MEDIA_MGMT_DOWNLOADS, MEDIA_MGMT_LIBRARY_IMPORT,
MEDIA_MGMT_LIBRARY_STORAGE, MEDIA_MGMT_ARCHIVE_WORKDIR, MEDIA_MGMT_PROCESSED,
MEDIA_MGMT_REKORDBOX_MCP_PATH, and MEDIA_MGMT_CONFIG_PATH all unset.

Use this to wrap every script invocation when running skill evals against
tests/fixtures/eval-sandbox — pass sandbox paths explicitly as arguments
instead of relying on env-derived defaults, which would otherwise silently
fall through to the real, production values.

Example:
  bash tests/fixtures/run-isolated.sh \
    bash skills/cleanup/scripts/cleanup-release.sh \
    tests/fixtures/eval-sandbox/downloads "Test Artist - Test Album"
HELP
  exit 0
fi

exec env \
  -u MEDIA_MGMT_DOWNLOADS \
  -u MEDIA_MGMT_LIBRARY_IMPORT \
  -u MEDIA_MGMT_LIBRARY_STORAGE \
  -u MEDIA_MGMT_ARCHIVE_WORKDIR \
  -u MEDIA_MGMT_PROCESSED \
  -u MEDIA_MGMT_REKORDBOX_MCP_PATH \
  -u MEDIA_MGMT_CONFIG_PATH \
  "$@"
