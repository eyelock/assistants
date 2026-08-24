---
"@eyelock-assistants/vendor-harness": patch
---

Fix vendor-harness agents losing their skills on every vendor except Claude Code.

The `skills:` frontmatter field is Claude Code-only. Cursor, Codex, and Copilot CLI parse the
agent and ignore the key — silently, with no warning — so the agent runs without any of the
knowledge it was built around and answers from the base model instead. Observed on Copilot CLI
v1.0.80: `harness-advisor` claimed Copilot rejects `{"source":"github","repo":...}` marketplace
sources, the exact opposite of the truth, while the same question asked without the agent
wrapper invoked `vendor-adapters` and answered correctly.

All four agents now name their skills as an explicit instruction in the prompt body, explain
that the frontmatter list is Claude-only, and keep the `skills:` key for the vendor that
honours it. `harness-advisor` is also told to propose changes rather than edit and commit them.

Documents the trap in `subagent-artifact` as a general portability rule — Claude-only
frontmatter fields (`skills`, `disallowedTools`, `maxTurns`, `effort`, `memory`, `background`,
`isolation`, `permissionMode`) are inert elsewhere, and model aliases like `model: sonnet` do
not resolve on Copilot (it warns and falls back to `auto`).
