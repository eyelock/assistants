#!/usr/bin/env bash
# Prints what a create-wheelhouse eval left in ./hq: its history, state,
# constitution, roster, desk, Beads setup and remotes.
set -uo pipefail
[ -d hq ] || { echo "(no ./hq folder)"; exit 0; }
cd hq
echo '$ git log --oneline --stat'; git log --oneline --stat 2>&1 | head -40
echo; echo '$ git status --short'; git status --short --untracked-files=all
echo; echo '$ git remote -v'; git remote -v
echo; echo '$ cat AGENTS.md'; cat AGENTS.md 2>/dev/null || echo "(missing)"
echo; echo '$ cat skills/roster/assets/roster.json'; cat skills/roster/assets/roster.json 2>/dev/null || echo "(missing)"
echo; echo '$ head -20 skills/roster/SKILL.md'; head -20 skills/roster/SKILL.md 2>/dev/null || echo "(missing)"
echo; echo '$ cat .agents/harness/plugin.json'; cat .agents/harness/plugin.json 2>/dev/null || echo "(missing)"
echo; echo '$ Beads'; if [ -d .beads ]; then echo ".beads present"; bd list --all --json >/dev/null 2>&1 && echo "bd works here" || echo "bd does not work here"; echo "database (named after the prefix): $(ls .beads/embeddeddolt 2>/dev/null | tr '\n' ' ')"; else echo "(no .beads)"; fi
echo; echo '$ Beads agent setup'; grep -l "BEGIN BEADS" AGENTS.md CLAUDE.md 2>/dev/null; ls -d .agents/skills/beads .claude .codex .cursor 2>/dev/null || echo "(none)"
echo; echo '$ cat .ynm/config.json'; cat .ynm/config.json 2>/dev/null || echo "(missing)"
echo; echo '$ bd dolt remote list'; bd dolt remote list 2>&1 | grep -v "^Warning" || true
echo; echo '$ bd config get dolt.auto-push'; bd config get dolt.auto-push 2>&1 | grep -v "^Warning" || true
if [ -d ../.eval/origin.git ]; then
  echo; echo '$ git -C .eval/origin.git for-each-ref (what reached the remote)'
  git -C ../.eval/origin.git for-each-ref | grep . || echo "(nothing)"
fi
