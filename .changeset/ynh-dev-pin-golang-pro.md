---
"@eyelock-assistants/ynh-dev": patch
---

The `ynh-dev` harness swaps its unpinned `golang-pro` include from `Jeffallan/claude-skills`, which scans with 2 active SkillSpector findings, for `golang-patterns` and `golang-testing` from `affaan-m/everything-claude-code`, pinned to a full commit SHA and scanning with 0 active findings. `ynh/ynh-dev/pinned-skills.md` records the publisher, licence, the files read, the scan result and the candidates rejected.

The harness gains an `AGENTS.md` saying that `go-lang` and the repository's own conventions win wherever the two new skills disagree with them.

The include sets `"instructions": false`, so only the two `SKILL.md` files reach the harness and not the repository's root `AGENTS.md`.
