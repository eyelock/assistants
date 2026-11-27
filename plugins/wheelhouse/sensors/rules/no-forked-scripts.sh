#!/usr/bin/env bash
# Rule sensor no-forked-scripts: the Wheelhouse holds a copy of a plugin script in its scripts/ folder, so the
# plugin's fixes never reach it. The doctor's check "plugin script copies", run through static-checks.sh (the
# doctor's own file, not a second copy of the check).
#
# Run in the Wheelhouse repository's root (the tree under test, as `ynh check` does). Plain bash and jq: runs
# without ynh. Prints one line per violation and exits 1 if there are any; exits 3 when jq is missing.
set -uo pipefail

[ "${1:-}" != "--help" ] || { echo "Usage: no-forked-scripts.sh   (run in a Wheelhouse repository's root; prints one line per violation, exits 1 if any)"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "jq is not installed" >&2; exit 3; }

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
doctor="$here/../../skills/doctor/scripts/static-checks.sh"
[ -f "$doctor" ] || { echo "the doctor skill's static-checks.sh is not at $doctor" >&2; exit 3; }

report=$(bash "$doctor" --dir .) || exit 3
violations=$(jq -r '.[] | select(.name == "plugin script copies" and .ok == false) | "\(.detail). Fix: \(.fix)"' <<<"$report")
[ -z "$violations" ] || printf '%s\n' "$violations"
[ -z "$violations" ]
