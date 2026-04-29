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

**Filing a GitHub issue:**
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
