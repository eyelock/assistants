# Notes: format hook not running in Cursor

- Plugin: acme-tools, from github.com/acme/acme-tools, installed at tag v1.4.0
- The hook config is hooks/hooks.json in that repo. The hook is the format-on-edit one:
  after a file edit it should run scripts/format.sh so the file gets prettier'd.
- Works fine in Claude Code 2.3.1 on the same repo.
- In Cursor 1.9.2 it never runs. No error anywhere, the file just stays unformatted.
  Tried 3 times, never fires, so it's consistent.
- To see it: install acme-tools v1.4.0 in Cursor, open any .ts file, ask the agent to add a
  function, look at the file afterwards: not formatted.
- The hooks.json uses "PostToolUse" with "matcher": "Edit|Write" and the nested
  {"matcher", "hooks": [...]} shape.
- Why it matters: our CI fails on formatting, so every Cursor user on the team gets a red
  build on their first push and has to run prettier by hand.
