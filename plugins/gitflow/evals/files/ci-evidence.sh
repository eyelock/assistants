#!/usr/bin/env bash
# Prints every file under .github/ after a ci run, for the judge, and whether
# each workflow parses as YAML (when ruby is there to check).
# Exit codes: 0 success.
set -uo pipefail

if [[ ! -d .github ]]; then
  echo "(no .github directory)"
  exit 0
fi
find .github -type f | sort | while read -r f; do
  echo "--- $f"
  cat "$f"
  if [[ "$f" == *.yml || "$f" == *.yaml ]] && command -v ruby >/dev/null; then
    ruby -ryaml -e 'YAML.load_file(ARGV[0]); puts "(parses as YAML)"' "$f" 2>&1 | tail -1
  fi
  echo
done
