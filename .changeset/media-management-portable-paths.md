---
"@eyelock-assistants/media-management": patch
---

Remove machine-specific absolute paths from shipped plugin files. `AGENTS.md` no longer lists a specific user's directories as "default paths" — path resolution is now env vars then `config.json` only, with `/setup` as the onboarding route when neither resolves. `.codex/config.toml` uses `/Users/YOUR_USERNAME/...` placeholders in its sandbox writable-roots and env examples, and the `/setup` skill's example output table uses `~/Downloads`. Previously these files carried the plugin author's home-directory paths, which other installs could silently fall back to.
