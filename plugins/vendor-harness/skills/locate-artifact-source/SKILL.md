---
name: locate-artifact-source
description: Determine where a harness artifact originated — tries multiple provenance strategies in order and returns the source repo, path, and ref when found.
---

Use this skill to trace a harness artifact back to its origin. Try strategies in order, stop at the first that yields a clear result.

**Strategy 1: YNH**
Run: `ynh ls --format json`
Look for the harness whose `path` contains the artifact. Extract: `installed_from.source` (repo), `installed_from.path` (the harness's directory in that repo; the artifact's source_path is this plus its path inside the harness), and `installed_from.ref` with `installed_from.sha` (the harness's `ref_installed` is the same commit).
The harness directory keeps the same record in `.agents/harness/installed.json`, so read that when `ynh` is not on PATH.
An artifact pulled in through the harness's `includes` comes from that include's `git`, `path` and `ref`, not from `installed_from`.
Works when: artifact was installed via a YNH harness.

**Strategy 2: Claude Code native plugin**
Check: `~/.claude/plugins/` and `.claude/plugins/` in the project
Look for a plugin directory matching the artifact name. Read its manifest for source repo.
Works when: artifact was installed directly via Claude Code marketplace.

**Strategy 3: Cursor native plugin**
Check: `~/.cursor/plugins/` and `.cursor/plugins/` in the project
Look for a plugin directory matching the artifact name. Read its manifest.
Works when: artifact was installed directly via Cursor marketplace.

**Strategy 4: Codex plugin cache**
Check: `~/.codex/plugins/cache/`
Look for a plugin directory matching the artifact name.
Works when: artifact was installed via Codex plugin system.

**Strategy 4b: Copilot CLI plugin install**
Check: `~/.copilot/installed-plugins/<marketplace>/<plugin-name>/` and
`~/.copilot/installed-plugins/_direct/<source-id>/`
(honour `COPILOT_HOME` if set — it relocates the whole config directory).
Faster: `copilot plugin list` (note: singular — `copilot plugins list` does not exist).
Also check `~/.copilot/agents/`, `~/.copilot/skills/`, and the marketplace cache
(`~/Library/Caches/copilot/marketplaces/` on macOS, `~/.cache/copilot/marketplaces/` on Linux,
or `COPILOT_CACHE_HOME`) for a registered marketplace index naming the source repo.
Works when: artifact was installed via Copilot CLI.

**Strategy 5: Git provenance**
Run: `git log --follow -1 --format="%H %s" -- <artifact-file-path>`
Get the commit that introduced the file. Then: `git remote -v` to find the origin remote.
If origin is on GitHub: extract owner/repo from remote URL.
Works when: artifact is in the current git repo (embedded, not installed externally).
Note: if found in current repo, check if this is a worktree — fix should go to the canonical branch, not the worktree.
Note: a commit only proves the file was added here. If the file sits under a directory with its own plugin manifest (see Strategy 6) naming a different repository, the repo vendored a copy: that manifest's repository is the source, so continue to Strategy 6 rather than stopping.

**Strategy 6: Manifest walk**
Walk up the directory tree from the artifact's location looking for `.claude-plugin/`, `.cursor-plugin/`, `.codex-plugin/`, `.agents/harness/`, `.ynh-plugin/` (deprecated), `.plugin/`, `.github/plugin/`, a root `plugin.json`, or `package.json` with a name field.
Read the manifest to find source repo reference.
Works when: artifact is part of a locally cloned plugin.

**Strategy 7: Ask the user**
All strategies failed or returned ambiguous results. Ask: "I wasn't able to automatically determine where this artifact came from. Do you know which repository it originated from?"

**Output:** end the answer with these five fields, labelled exactly so (callers such as submit-feedback read them), after any explanation:
- source_repo: github.com/owner/repo (or unknown)
- source_path: path within repo (or unknown)
- source_ref: branch/tag/commit (or unknown)
- strategy_used: which strategy succeeded, by number and name (e.g. "5: Git provenance")
- confidence: high / medium / low
