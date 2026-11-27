#!/usr/bin/env bash
# Rule sensor work-in-beads (constitution rule 2): work lives in Beads, so the Wheelhouse has a work graph
# (a .beads/ folder) and none of Beads' own agent setup, which tells agents to keep memory in `bd remember`
# and splits it away from ynm. The doctor's check "no Beads agent setup", run through static-checks.sh.
#
# Run in the Wheelhouse repository's root (the tree under test, as `ynh check` does). Plain bash and jq: runs
# without ynh, bd or ynm. Prints one line per violation and exits 1 if there are any; exits 3 when jq is missing.
set -uo pipefail

[ "${1:-}" != "--help" ] || { echo "Usage: work-in-beads.sh   (run in a Wheelhouse repository's root; prints one line per violation, exits 1 if any)"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "jq is not installed" >&2; exit 3; }

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
doctor="$here/../../skills/doctor/scripts/static-checks.sh"
[ -f "$doctor" ] || { echo "the doctor skill's static-checks.sh is not at $doctor" >&2; exit 3; }

violations=0
if [ ! -d .beads ]; then
  echo "no .beads/ in the Wheelhouse repository, so its work has no graph. Fix: bd init --skip-agents --non-interactive --role maintainer --prefix <wheelhouse name>"
  violations=1
fi
report=$(bash "$doctor" --dir .) || exit 3
setup=$(jq -r '.[] | select(.name == "no Beads agent setup" and .ok == false) | "\(.detail). Fix: \(.fix)"' <<<"$report")
if [ -n "$setup" ]; then
  printf '%s\n' "$setup"
  violations=$((violations + 1))
fi
[ "$violations" -eq 0 ]
