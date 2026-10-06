#!/usr/bin/env bash
# Sandbox for locate-artifact-source: the user's project, github.com/acme/shop-web,
# has a third-party plugin vendored into tools/plugins/lint-kit and committed.
# git history says the files arrived in acme/shop-web, but the plugin's own
# manifest names its real home: github.com/tools-co/lint-kit at 1.4.0.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail

git init -q -b main .
echo ".eval/" >> .git/info/exclude
git remote add origin https://github.com/acme/shop-web.git
echo "# shop web" > README.md
git add README.md && git commit -qm "chore: Initial commit"

plugin=tools/plugins/lint-kit
mkdir -p "$plugin/.claude-plugin" "$plugin/skills/style-check"
cat > "$plugin/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "lint-kit",
  "version": "1.4.0",
  "description": "Style and lint checks for TypeScript projects",
  "author": { "name": "Tools Co" },
  "repository": "https://github.com/tools-co/lint-kit",
  "license": "MIT"
}
JSON
cat > "$plugin/skills/style-check/SKILL.md" <<'MD'
---
name: style-check
description: Check TypeScript files against the team style guide before a commit.
---

Run `npx eslint --max-warnings=0` on the changed files and report each finding.
MD
git add tools && git commit -qm "chore: Vendor lint-kit plugin for CI"
echo "export const price = (n: number) => n.toFixed(2);" > price.ts
git add price.ts && git commit -qm "feat: Format prices"

# ynh is installed but has no harnesses (logs its calls).
cat > "$EVAL_BIN/ynh" <<STUB
#!/bin/sh
printf '%s\n' "ynh \$*" >> "$EVAL_STUB_LOG"
case "\$*" in
  *json*) printf '{\n  "capabilities": "0.9.0",\n  "schema_version": 3,\n  "harnesses": []\n}\n' ;;
  *) echo "No harnesses installed." ;;
esac
STUB
chmod +x "$EVAL_BIN/ynh"
