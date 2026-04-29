---
name: compose-feedback
description: Compose a structured feedback report for a harness artifact problem — gathers required context and formats it clearly for submission as a GitHub issue, PR description, or message.
---

Use this skill to build a well-structured feedback report before submitting. A good report has enough context for the maintainer to reproduce and understand the problem without follow-up questions.

**Required fields for a complete report:**

1. **Artifact**: what is it? (name, type: skill/agent/MCP/hook/startup-context, vendor)
2. **Source**: where does it come from? (repo, path, version/ref if known)
3. **Expected behavior**: what should have happened?
4. **Actual behavior**: what happened instead? (be specific — error messages, wrong output, missing behavior)
5. **Reproduction**: how to reproduce (what invocation, what context, what vendor/version)
6. **Impact**: how does this affect the user's work?

**Optional but useful:**
- Vendor version (e.g., Claude Code version, Cursor version)
- Harness/plugin version
- Whether the behavior is consistent or intermittent
- Any workaround discovered

**Issue title format:**
`[artifact-type] Brief description of the problem`
Example: `[hooks-artifact] PreToolUse hook not firing in Cursor plugin format`

**PR description format (for fix submissions):**
- Summary: what the problem was
- Root cause: why it happened
- Fix: what was changed and why
- Testing: how to verify the fix

Gather missing fields by asking the user one question at a time before composing the final report. Do not submit with unknown or vague fields — a weak report is worse than no report.
