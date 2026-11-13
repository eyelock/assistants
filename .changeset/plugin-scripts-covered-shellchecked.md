---
"@eyelock-assistants/wheelhouse": patch
---

Every shell script the wheelhouse plugin ships is now covered by a test and linted. `memory-checks.sh` and `tracker-generic.sh` gain tests, a new check fails when a script under `skills/*/scripts/` is named by no test, and CI runs shellcheck (warnings and up) and the plugin's tests on Linux and macOS. The warnings that raised are fixed in `check.sh`, `wake.sh`, `inbox.sh` and `open-pr.sh`, with no change in behaviour.
