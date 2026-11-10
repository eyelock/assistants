---
"@eyelock-assistants/wheelhouse": patch
---

`patrol.sh` resolves its own folder before it moves into `--dir`, so a relative script path with `--dir` elsewhere finds `patrol-read.jq` and `patrol-diff.jq` instead of failing every repository; a test covers it. The CI watcher template's Reaping step 2 matches a merged pull request to its bead by the bead's `PR:` note first, then the bead id in the pull request's title, then its body, then the bead's `external_ref`. The reaping eval moves from the `patrol` skill's evals to `add-seat`'s, beside the template it grades.
