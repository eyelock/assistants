#!/usr/bin/env bash
# Shared by the refresh eval setups: a small Wheelhouse (the hq desk, seats eno and wick) in git, and
# a ynh stub that logs each call, lists every seat as installed, and refuses `trust`. Source it, make
# a change, and commit it: the refresh runs over the diff of the last commit.
set -euo pipefail

refresh_wheelhouse() {
  git init -q -b main .
  echo ".eval/" >> .git/info/exclude
  mkdir -p skills/roster/assets scripts harnesses/eno/.agents/harness harnesses/wick/.agents/harness .agents/harness
  echo "# hq" > AGENTS.md
  echo "#!/bin/sh" > scripts/wake.sh
  jq -n '{name: "hq", version: "0.1.0", workspace: ["../api"], includes: [{git: "https://github.com/eyelock/assistants", path: "plugins/wheelhouse"}]}' > .agents/harness/plugin.json
  for s in eno wick; do
    echo "# $s" > "harnesses/$s/AGENTS.md"
    jq -n --arg n "$s" '{name: $n, version: "0.1.0", includes: [{git: "https://github.com/eyelock/assistants", path: "plugins/wheelhouse"}, {git: "../..", pick: ["skills/roster"]}]}' > "harnesses/$s/.agents/harness/plugin.json"
  done
  jq -n '{seats: [{name: "Hq", command: "hq", group: "desk", harness: "."}, {name: "Eno", command: "eno", group: "crew", harness: "harnesses/eno"}, {name: "Wick", command: "wick", group: "workers", harness: "harnesses/wick"}]}' > skills/roster/assets/roster.json
  git add -A && git commit -qm "chore: A small Wheelhouse"
  cat > "$EVAL_BIN/ynh" <<'SH'
#!/bin/sh
printf 'ynh %s\n' "$*" >> "$EVAL_STUB_LOG"
case "$1" in
  ls) echo '{"harnesses":[{"id":"local/hq","name":"hq","includes":[]},{"id":"local/eno","name":"eno","includes":[]},{"id":"local/wick","name":"wick","includes":[]}]}' ;;
  install) echo "installed $2" ;;
  trust) echo "the eval stub refuses ynh trust: only the human accepts" >&2; exit 1 ;;
esac
SH
  chmod +x "$EVAL_BIN/ynh"
}
