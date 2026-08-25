---
"@eyelock-assistants/vendor-harness": patch
---

Fix agent `tools:` frontmatter stripping capability on Copilot, and correct the marketplace
source-type table with tested results.

`tools:` is restrictive and the two vendors do not share a tool namespace. A Claude-authored
list (`Read, Write, WebFetch, Bash`) leaves an agent without those capabilities on Copilot.
This broke `vendor-sync`, which could not fetch vendor documentation at all — the only thing
it exists to do. All four agents now list both vocabularies.

GitHub's documented custom-agent tool aliases turn out not to work in `tools:` either: `web`
is published as the alias for `WebFetch`/`WebSearch`, and neither grants fetch — only the raw
`web_fetch` does. Recorded as an upstream docs bug.

Corrects the marketplace source-type table. It claimed Copilot supports `npm`, taken from
issue prose rather than testing; `npm` is rejected, as are `archive` and `command`, exactly
like `git-subdir`. All seven types were probed against Copilot CLI v1.0.80 — Copilot accepts
exactly three: relative path, `github` (with optional `path`), and `url`.

Also makes `provenance-detective` actually run its committer check rather than reporting
`unknown` without trying.
