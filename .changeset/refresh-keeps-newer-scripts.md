---
"@eyelock-assistants/wheelhouse": patch
---

`refresh.sh --update` no longer overwrites a script in the Wheelhouse's `scripts/` that carries changes the plugin never shipped: it copies only a script that is a version the plugin once shipped, and lists any other in `upstream.pluginScriptsKept` with its diff and a note (it also keeps one when the plugin's history can't say, as with ynh's depth-1 cache, and then says so and to pass `--plugin` a full clone). `open-pr.sh` treats a bead whose `external_ref` is a pull request URL as a review fix (a dry run reports `review_fix`, a real run refuses), as ynw's own copy already did. The plugin's docs (work-graph skill, the starter-team dispatcher, reviewer and worker templates) now say a review fix bead's `external_ref` is its pull request's URL and what `open-pr.sh` does with it.
