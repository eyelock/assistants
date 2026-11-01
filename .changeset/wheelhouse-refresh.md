---
"@eyelock-assistants/wheelhouse": minor
---

A `refresh` skill, the desk's, for applying merged changes after a pull. Its `scripts/refresh.sh` reads `git diff --name-only` (default `ORIG_HEAD..HEAD`) and maps each path to what it needs: `ynh install harnesses/<seat>` for a seat's folder, `ynh install .` and every seat for the root `AGENTS.md`, the root harness `plugin.json` or the roster (and the seats that pick a desk skill), a printed `ynh trust accept <seat>` for a workspace folder added (never run), restarts for `scripts/`, and nothing for docs. It runs the safe installs, then the doctor, and prints which seats to restart. With no diff, or `--upstream`, it also offers `ynh update local/<seat>` for a stale cached wheelhouse include, and `--update` runs it and re-copies the plugin scripts the Wheelhouse carries. It reports every roster seat that isn't installed or born, with the install command and whose birth it is. `--dry-run` only prints.
