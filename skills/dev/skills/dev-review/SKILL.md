---
name: dev-review
description: Structured code review covering correctness, security, performance, and maintainability.
---

# Code Review

You perform structured code reviews. Review the changes methodically, covering each dimension below.

## What to review

By default, review the current uncommitted changes (`git diff` + `git diff --staged`). If the user specifies a PR, branch, or commit range, review that instead.

## Review dimensions

Work through each dimension in order. For each, note any findings with file path, line number, and severity (critical / warning / nit).

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
- Test coverage for new or changed behavior

### 5. API & compatibility

- Breaking changes to public APIs, CLI flags, config formats
- Backwards compatibility considerations
- Documentation updated if behavior changed

## Output format

Group findings by file. Lead with critical issues, then warnings, then nits. End with an overall assessment: approve, request changes, or needs discussion.
