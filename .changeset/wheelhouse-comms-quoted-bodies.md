---
"@eyelock-assistants/wheelhouse": minor
---

The `comms` skill gains a rule for posting: a pull request description, review or comment body is written to a file (the Write tool, or a quoted heredoc such as `<<'EOF'`) and posted with `--body-file` or `gh api --input`, never from an unquoted heredoc, where the shell runs every backtick span as a command. A value such as a commit SHA goes in afterwards with `sed` or `jq`.
