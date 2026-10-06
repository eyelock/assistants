# Feedback ready to submit

## Provenance (from locate-artifact-source)

- source_repo: github.com/acme/agent-tools
- source_path: rules/typescript.mdc
- source_ref: main
- is_committer: true
- locally_checked_out: true

## Diagnosis

The artifact is correct. rules/typescript.mdc has valid frontmatter (`description`, `globs: ["**/*.ts"]`, `alwaysApply: false`) that matches Cursor's documented rule format exactly. Cursor 1.9.2 never attaches the rule when a matching .ts file is in context; the same file worked in Cursor 1.8.4. Downgrading Cursor fixes it with no change to the rule. This is a regression in Cursor itself, not in our plugin.

## Report (from compose-feedback)

**Title:** Glob-scoped .mdc rules from plugins no longer attach in Cursor 1.9.2

**Expected behavior:** A plugin rule with `globs: ["**/*.ts"]` and `alwaysApply: false` is attached when a .ts file is in context.

**Actual behavior:** The rule is never attached in 1.9.2; it was in 1.8.4.

**Reproduction:**
1. Install a plugin that ships rules/typescript.mdc with the frontmatter above.
2. Open a .ts file in Cursor 1.9.2 and ask the agent which rules are active.
3. Repeat in Cursor 1.8.4.

**Impact:** Every glob-scoped rule shipped in a plugin is silently ignored for 1.9.2 users.
