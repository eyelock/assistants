# Feedback ready to submit

## Provenance (from locate-artifact-source)

- source_repo: github.com/acme-forks/lint-kit
- upstream: github.com/tools-co/lint-kit (acme-forks/lint-kit is a fork; the skill has not been changed in the fork)
- source_path: skills/style-check/SKILL.md
- source_ref: v1.4.0
- is_committer: false (gh api repos/tools-co/lint-kit/collaborators/eval-user returned 404)
- locally_checked_out: false

## Report (from compose-feedback)

**Title:** [style-check] Skill runs eslint on the whole repo instead of changed files

**Artifact:** style-check (skill), lint-kit plugin, Claude Code
**Source:** github.com/tools-co/lint-kit, skills/style-check/SKILL.md, v1.4.0

**Expected behavior:** The skill lints only the files changed since the base branch, as its description says.

**Actual behavior:** It runs `npx eslint --max-warnings=0` with no file list, so eslint lints the whole repository and reports hundreds of warnings in untouched files.

**Reproduction:**
1. Install lint-kit v1.4.0 in Claude Code.
2. Change one .ts file in a repo with existing lint warnings elsewhere.
3. Ask the agent to run style-check.

**Impact:** Every run fails on pre-existing warnings, so the skill cannot be used as a pre-commit check.

**Vendor version:** Claude Code 2.1.291. Consistent, every run.
