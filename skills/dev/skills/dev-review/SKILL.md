---
name: dev-review
description: Structured code review covering correctness, security, performance, and maintainability. Use when asked to review a diff, patch, pull request or uncommitted changes, or to decide whether a change should be approved.
---

# Code Review

You perform structured code reviews. Review the changes methodically, covering each dimension below.

## What to review

By default, review the current uncommitted changes (`git diff` + `git diff --staged`). If the user specifies a PR, branch, or commit range, review that instead.

- **Check the change against its claim.** Read the PR description or the user's summary first. A behavior change in a change described as a refactor, rename, or tidy-up is a finding in itself, even when the new behavior is fine.
- **Follow the change past the diff.** Where it changes a function, flag, config key, or format, look for the callers, scripts, docs, and tests that use it, and read the existing tests for the code touched.
- **Keep to the change.** Problems in code the change does not touch go in a separate *Pre-existing* list. They do not count toward the verdict.

## Review dimensions

Work through each dimension in order. For each, note any findings with file path, line number, and severity (see *Severity*).

### 1. Correctness

- Does the code do what it claims to?
- Are edge cases handled (nil, empty, overflow, concurrent access)?
- Are error paths correct — no swallowed errors, no panics leaking?

### 2. Security

- Input validation at system boundaries (user input, API payloads, file paths)
- No secrets, credentials, or tokens in code or config
- SQL/command injection, XSS, path traversal
- Dependency versions — any known vulnerabilities?

### 3. Performance

- Unnecessary allocations or copies in hot paths
- N+1 queries, unbounded loops, missing pagination
- Appropriate use of caching, indexing, batching

### 4. Maintainability

- Clear naming — can you understand the code without the PR description?
- Appropriate abstraction level — not over-engineered, not copy-pasted
- Test coverage for new or changed behavior: a bug fix with no test that fails without the fix is a finding

### 5. API & compatibility

- Breaking changes to public APIs, CLI flags, config formats
- Backwards compatibility considerations
- Documentation updated if behavior changed

## Severity

Use exactly three levels. A severity says what the author must do, not how strongly you feel about it.

- **critical**: must be fixed before merge. An exploitable security hole, a leaked secret, data loss or corruption, wrong results or a crash on the normal path, or a breaking change to a public API, CLI, or config with no migration path.
- **warning**: should be fixed in this change, or deferred to a follow-up the author explicitly takes on. Edge cases and error paths that misbehave, missing validation, behavior changes the description does not mention, new or changed behavior with no test, docs left describing the old behavior, and performance problems that will show at realistic scale.
- **nit**: optional; the author may ignore it. Naming, wording, comments, formatting, and small simplifications. A naming quibble is a nit however much you prefer your name.

When torn between two levels, pick the lower and say what would make it the higher. Do not pad a clean change with findings: when you find nothing, say so.

## Output format

Each finding is one entry:

```
path/to/file.ext:LINE (or LINE-LINE) | severity | what is wrong. Why it matters: what breaks, for whom. Fix: the concrete change.
```

Line numbers are lines in the new version of the file, so the author can jump to them. Reviewing a patch, count them from the hunk header: in `@@ -a,b +c,d @@` the first context or added line is line `c` of the new file. Never cite a line of the patch file itself.

Group findings by file, and within each file list critical, then warning, then nit. After the files, list any *Pre-existing* problems. End with the verdict as the last line, following from the findings:

- **Request changes**: any critical or warning finding
- **Approve**: only nits, or nothing
- **Needs discussion**: the right fix is a design decision the author or team has to make
