---
name: submit-feedback
description: Select the right feedback channel and submit — GitHub issue, GitHub PR, email, or message — based on provenance, contributor status, and local checkout availability.
---

Use this skill after compose-feedback has produced a complete report. Select the channel, handle edge cases, and execute the submission.

**Channel selection:**

| Condition | Channel |
|-----------|---------|
| is_committer + locally_checked_out | Offer PR (ask first — they may prefer an issue) |
| is_committer + not locally_checked_out | Ask: clone and open PR, or file issue? |
| not_committer + GitHub repo found | File GitHub issue |
| not_committer + no GitHub repo | Email or message (ask for contact) |
| no source repo found | Ask user how they want to proceed |

**When the problem is the vendor, not the artifact:**

If the artifact is correct and the vendor's own behavior or documentation is at fault, the
report belongs on the vendor's tracker, not the artifact's repo:

| Vendor | Tracker |
|--------|---------|
| Claude Code | https://github.com/anthropics/claude-code |
| Claude plugin marketplace | https://github.com/anthropics/claude-plugins-official |
| GitHub Copilot CLI | https://github.com/github/copilot-cli |
| OpenAI Codex | https://github.com/openai/codex |
| Cursor | https://forum.cursor.com |
| Agent Plugins (Open Plugin Spec) | https://github.com/agentplugins/agent-plugins-spec |

Search for an existing report first — cross-vendor format incompatibilities are usually
already filed. Link the existing issue rather than duplicating it.

**Filing a GitHub issue:**
Search the target repo before filing, whoever the artifact or vendor is:
`gh issue list --repo owner/repo --state all --search "<key words>"`.
If an open report already covers the problem, do not file a second one, even when
the user said to file it now: their go-ahead covers the text, not a duplicate. Give
them the existing issue's link and offer to add what the new report knows (the
reproduction, the version, the impact) as a comment on it. File only when nothing
matches, or when the existing issue is closed and the problem is back (then link it
from the new one).

`gh issue create --repo owner/repo --title "title" --body "body"`
Label suggestions: `bug`, `enhancement`, `vendor-compat` (if vendor-specific)

**Opening a PR:**
Assumes local checkout exists. Create branch from main/develop:
`git checkout -b fix/artifact-name-brief-description`
Make the change. Then use the push skill or `gh pr create`.

**Edge cases:**
- `gh` CLI not available: provide the GitHub web URL and the formatted issue body for manual submission
- Private repo with no issue tracker: fall back to email if maintainer contact is known
- Repo requires issue template: fetch the template first (`gh issue list --repo owner/repo` then check .github/ISSUE_TEMPLATE/)
- Fork: file issue against the upstream repo, not the fork

Always show the user the exact command or URL before executing. Confirm before submitting.
