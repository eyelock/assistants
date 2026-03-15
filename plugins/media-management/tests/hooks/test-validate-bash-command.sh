#!/usr/bin/env bash
set -uo pipefail

# shellcheck disable=SC2034
FIXTURES_DIR="${1:-tests/fixtures}"
PROJECT_ROOT="${2:-.}"
HOOK="$PROJECT_ROOT/hooks/validate-bash-command.sh"

pass=0
fail=0

run_hook() {
  local json="$1"
  echo "$json" | bash "$HOOK" 2>/dev/null
  return $?
}

assert_blocked() {
  local desc="$1"
  local json="$2"
  if run_hook "$json"; then
    echo "FAIL: $desc — expected BLOCK (exit 2), got ALLOW (exit 0)"
    ((fail++)) || true
  else
    local rc=$?
    if [[ $rc -eq 2 ]]; then
      ((pass++)) || true
    else
      echo "FAIL: $desc — expected exit 2, got exit $rc"
      ((fail++)) || true
    fi
  fi
}

assert_allowed() {
  local desc="$1"
  local json="$2"
  if run_hook "$json"; then
    ((pass++)) || true
  else
    echo "FAIL: $desc — expected ALLOW (exit 0), got exit $?"
    ((fail++)) || true
  fi
}

# --- Extraction rules ---

assert_blocked "Block unzip to Downloads root (~)" \
  '{"tool_name":"Bash","tool_input":{"command":"unzip file.zip -d ~/Downloads"}}'

assert_blocked "Block unzip to Downloads root (absolute)" \
  "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"unzip file.zip -d $HOME/Downloads\"}}"

assert_allowed "Allow unzip to Downloads subfolder (~)" \
  '{"tool_name":"Bash","tool_input":{"command":"unzip file.zip -d ~/Downloads/Artist - Album/"}}'

assert_allowed "Allow unzip to Downloads subfolder (absolute)" \
  "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"unzip file.zip -d $HOME/Downloads/My Album/\"}}"

# --- rm rules ---

assert_blocked "Block rm -rf Downloads" \
  '{"tool_name":"Bash","tool_input":{"command":"rm -rf ~/Downloads"}}'

assert_blocked "Block rm -rf Music (absolute)" \
  "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf $HOME/Music\"}}"

assert_blocked "Block rm -rf archive (absolute)" \
  "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf $HOME/Storage/Music\"}}"

assert_allowed "Allow rm -rf on subfolder" \
  "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf $HOME/Downloads/Artist - Album\"}}"

# --- Command chaining bypass ---

assert_blocked "Block unzip to Downloads root with && chain" \
  '{"tool_name":"Bash","tool_input":{"command":"unzip file.zip -d ~/Downloads && echo done"}}'

assert_blocked "Block rm -rf Downloads with ; chain" \
  '{"tool_name":"Bash","tool_input":{"command":"rm -rf ~/Downloads ; echo done"}}'

assert_blocked "Block unzip to Downloads root with | pipe" \
  '{"tool_name":"Bash","tool_input":{"command":"unzip file.zip -d ~/Downloads | tee log.txt"}}'

# --- .env credential rules ---

assert_blocked "Block cat on .env file" \
  '{"tool_name":"Bash","tool_input":{"command":"cat /project/.env"}}'

assert_blocked "Block cat on .env with space after" \
  '{"tool_name":"Bash","tool_input":{"command":"cat /project/.env | grep SECRET"}}'

assert_allowed "Allow word containing env in path" \
  '{"tool_name":"Bash","tool_input":{"command":"ffmpeg -i /tmp/environment.mp3 out.mp3"}}'

assert_allowed "Allow .env.example (no slash-dot-env boundary)" \
  '{"tool_name":"Bash","tool_input":{"command":"cat /project/.env.example"}}'

assert_allowed "Allow .env_backup style path" \
  '{"tool_name":"Bash","tool_input":{"command":"cat /project/.env_backup"}}'

# --- Other credential rules ---

assert_blocked "Block .ssh access" \
  '{"tool_name":"Bash","tool_input":{"command":"cat ~/.ssh/id_rsa"}}'

assert_blocked "Block .aws access" \
  '{"tool_name":"Bash","tool_input":{"command":"cat ~/.aws/credentials"}}'

assert_blocked "Block .gnupg access (absolute)" \
  "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cat $HOME/.gnupg/private.key\"}}"

# --- Normal commands ---

assert_allowed "Allow ffprobe" \
  '{"tool_name":"Bash","tool_input":{"command":"ffprobe -v quiet file.mp3"}}'

assert_allowed "Allow ls" \
  '{"tool_name":"Bash","tool_input":{"command":"ls -la ~/Downloads/"}}'

assert_allowed "Allow cp" \
  "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cp track.mp3 $HOME/Music/\"}}"

# --- stderr contains reason ---

stderr_output=$(echo '{"tool_name":"Bash","tool_input":{"command":"unzip file.zip -d ~/Downloads"}}' | bash "$HOOK" 2>&1 >/dev/null || true)
if echo "$stderr_output" | grep -qi "BLOCKED"; then
  ((pass++)) || true
else
  echo "FAIL: Blocked message should contain 'BLOCKED'"
  ((fail++)) || true
fi

# --- jq guard: malformed input should block ---

stderr_output=$(echo 'NOT JSON' | bash "$HOOK" 2>&1 >/dev/null || true)
if echo "$stderr_output" | grep -qi "BLOCKED"; then
  ((pass++)) || true
else
  echo "FAIL: Malformed input should be blocked"
  ((fail++)) || true
fi

echo "Hook tests: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
