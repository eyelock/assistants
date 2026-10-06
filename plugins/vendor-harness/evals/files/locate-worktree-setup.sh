#!/usr/bin/env bash
# Sandbox for locate-artifact-source: github.com/acme/agent-tools is cloned at
# .eval/agent-tools (default branch main), and the run's directory is a linked
# worktree of it on feat/faster-deploy. The deploy skill was written in this
# repo, so git provenance is the answer, but the fix belongs on main, not on
# the worktree's feature branch.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail

work="$PWD"
main="$work/.eval/agent-tools"
mkdir -p "$main"
cd "$main"
git init -q -b main .
git remote add origin git@github.com:acme/agent-tools.git
mkdir -p .claude-plugin skills/deploy
printf '{\n  "name": "agent-tools",\n  "version": "0.8.0",\n  "repository": "https://github.com/acme/agent-tools"\n}\n' > .claude-plugin/plugin.json
printf -- '---\nname: deploy\ndescription: Deploy the current service to staging.\n---\n\nRun `make deploy ENV=staging` and wait for the health check.\n' > skills/deploy/SKILL.md
git add -A && git commit -qm "feat: Add deploy skill"
git branch feat/faster-deploy

# The run's directory becomes the linked worktree.
cd "$work"
tmp="$main.wt"
git -C "$main" worktree add -q "$tmp" feat/faster-deploy
mv "$tmp/.git" "$work/.git"
cp -R "$tmp/." "$work/"
rm -rf "$tmp"
git -C "$main" worktree repair "$work" >/dev/null 2>&1 || true
echo ".eval/" >> "$main/.git/info/exclude"

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
