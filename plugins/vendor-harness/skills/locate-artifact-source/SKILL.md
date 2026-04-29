---
name: locate-artifact-source
description: Determine where a harness artifact originated — tries multiple provenance strategies in order and returns the source repo, path, and ref when found.
---

Use this skill to trace a harness artifact back to its origin. Try strategies in order, stop at the first that yields a clear result.

**Strategy 1: YNH**
Run: `ynh ls --format json`
Look for the harness containing the artifact. Extract: `installed_from.source`, `installed_from.path`, `installed_from.ref_installed`.
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

**Strategy 5: Git provenance**
Run: `git log --follow -1 --format="%H %s" -- <artifact-file-path>`
Get the commit that introduced the file. Then: `git remote -v` to find the origin remote.
If origin is on GitHub: extract owner/repo from remote URL.
Works when: artifact is in the current git repo (embedded, not installed externally).
Note: if found in current repo, check if this is a worktree — fix should go to the canonical branch, not the worktree.

**Strategy 6: Manifest walk**
Walk up the directory tree from the artifact's location looking for `.claude-plugin/`, `.cursor-plugin/`, `.ynh-plugin/`, or `package.json` with a name field.
Read the manifest to find source repo reference.
Works when: artifact is part of a locally cloned plugin.

**Strategy 7: Ask the user**
All strategies failed or returned ambiguous results. Ask: "I wasn't able to automatically determine where this artifact came from. Do you know which repository it originated from?"

**Output:**
- source_repo: github.com/owner/repo (or unknown)
- source_path: path within repo (or unknown)
- source_ref: branch/tag/commit (or unknown)
- strategy_used: which strategy succeeded
- confidence: high / medium / low
