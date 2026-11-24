---
"@eyelock-assistants/wheelhouse": minor
---

wake.sh splits three ways, each file doing one job: `sync.sh` runs the session-start and `--end` syncs, `wake.sh` gathers the seat's JSON, and `render-wake.jq` lays that JSON out as the Markdown block. `wake.sh` calls the other two, so the command seats run, its flags, its JSON and its block are unchanged. The three files sit together in the wake skill's `scripts/` folder, where ynh installs them; no Wheelhouse copies them. SkillSpector reads each whole, so the temporary parse-limit baseline rule for `wake.sh` goes.
