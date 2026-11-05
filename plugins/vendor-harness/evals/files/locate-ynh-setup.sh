#!/usr/bin/env bash
# Sandbox for locate-artifact-source: a ynh home in ynh-home/ with one
# installed harness, gitflow, from github.com/eyelock/assistants
# (plugins/gitflow, ref develop at a4968ff). The harness's own manifests do
# not name a repository; ynh ls and .agents/harness/installed.json do. The
# run's directory is also the user's project, a git repo whose origin is
# github.com/acme/website, which never tracked the harness. ynh is a stub that
# prints that state and logs its calls.
# Exit codes: 0 success, 3 tool error.
set -euo pipefail

git init -q -b main .
printf '.eval/\nynh-home/\n' >> .git/info/exclude
git remote add origin git@github.com:acme/website.git
echo "# acme website" > README.md
git add README.md && git commit -qm "chore: Initial commit"

harness="$PWD/ynh-home/harnesses/github.com--eyelock--assistants--gitflow"
mkdir -p "$harness/.agents/harness" "$harness/.claude-plugin" "$harness/skills/push"
cat > "$harness/.agents/harness/installed.json" <<'JSON'
{
  "source_type": "git",
  "source": "https://github.com/eyelock/assistants",
  "ref": "develop",
  "sha": "a4968ff7363ae68709cca8bce1c2fbb44677f2fe",
  "path": "plugins/gitflow",
  "installed_at": "2026-08-29T18:23:23Z"
}
JSON
printf '{\n  "name": "gitflow",\n  "version": "0.2.0",\n  "author": { "name": "eyelock" }\n}\n' > "$harness/.claude-plugin/plugin.json"
printf -- '---\nname: push\ndescription: Push the branch and open a PR against develop.\n---\n\nPush with `git push -u origin HEAD`, then `gh pr create --base develop`.\n' > "$harness/skills/push/SKILL.md"

cat > "$EVAL_BIN/ynh-ls.json" <<JSON
{
  "capabilities": "0.9.0",
  "schema_version": 3,
  "ynh_version": "0.9.2",
  "harnesses": [
    {
      "id": "github.com/eyelock/assistants/gitflow",
      "name": "gitflow",
      "kind": "git",
      "version_installed": "0.2.0",
      "default_vendor": "",
      "path": "$harness",
      "ref_installed": "a4968ff7363ae68709cca8bce1c2fbb44677f2fe",
      "is_pinned": true,
      "installed_from": {
        "source_type": "git",
        "source": "https://github.com/eyelock/assistants",
        "ref": "develop",
        "sha": "a4968ff7363ae68709cca8bce1c2fbb44677f2fe",
        "path": "plugins/gitflow",
        "installed_at": "2026-08-29T18:23:23Z"
      },
      "artifacts": { "skills": 1, "agents": 0, "rules": 0, "commands": 0 },
      "includes": [],
      "delegates_to": []
    }
  ]
}
JSON

cat > "$EVAL_BIN/ynh" <<STUB
#!/bin/sh
printf '%s\n' "ynh \$*" >> "$EVAL_STUB_LOG"
case "\$*" in
  "ls --format json"|"ls --format=json") cat "$EVAL_BIN/ynh-ls.json" ;;
  ls*)
    echo "ID                                     KIND  VENDOR  SOURCE                               ARTIFACTS"
    echo "github.com/eyelock/assistants/gitflow  git   -       https://github.com/eyelock/assistants  1" ;;
  *) echo "ynh: '\$1' is not available in this sandbox; try ynh ls --format json" >&2; exit 1 ;;
esac
STUB
chmod +x "$EVAL_BIN/ynh"
