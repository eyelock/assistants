#!/usr/bin/env bash
# Eject the disc in the optical drive.
# Usage: eject-disc.sh
# Output: JSON to stdout
# Exit codes: 0=ejected, 2=no disc, 3=eject failed

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage: eject-disc.sh

Eject the disc in the optical drive. Takes no arguments. Use it only once
the disc's rip is verified and its files are where they belong.

Output: JSON to stdout
  {"ejected": true}

Exit codes:
  0  Ejected
  2  No disc in the drive
  3  The drive would not eject (something may still have the disc open)
HELP
  exit 0
fi

if drutil status 2>/dev/null | grep -q "No Media Inserted"; then
  echo "Error: no disc in the drive" >&2
  exit 2
fi
if ! drutil eject >&2; then
  echo "Error: the drive would not eject" >&2
  exit 3
fi
echo '{"ejected": true}'
