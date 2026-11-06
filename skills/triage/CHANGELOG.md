# @eyelock-assistants/triage-skills

## 0.2.0

### Minor Changes

- [#46](https://github.com/eyelock/assistants/pull/46) [`645c494`](https://github.com/eyelock/assistants/commit/645c4949c5f5b0b5ef13a6fb3af9be63acfa507e) Thanks [@eyelock](https://github.com/eyelock)! - Add five read-only platform harnesses (GitHub, Slack, Gmail, Calendar, Drive) that answer what is waiting on you, what you are waiting on, and what to act on now or soon. Add the triage skills they share and the voice and reply-styles skills. Every skill ships evals.

- [#57](https://github.com/eyelock/assistants/pull/57) [`8b544e4`](https://github.com/eyelock/assistants/commit/8b544e403c1d861d63ae4c8d29b6fb380376d66f) Thanks [@eyelock](https://github.com/eyelock)! - The common triage list grows by three questions, `my-commitments` (what I promised and have not done), `catch-up` (where a conversation, thread or topic stands) and `find` (where something was said), and `add-triage-question` says when a new question belongs on the list and when it does not, keeps every platform harness in step with the list (`scripts/triage-questions.mjs check` and `sync`), and is checked by `pnpm test`. The iMessage harness is the first to answer all of them; the others are marked `todo` in the list and follow in their own changes. The iMessage `commitments` focus is renamed `my-commitments`.

### Patch Changes

- [#67](https://github.com/eyelock/assistants/pull/67) [`e41695c`](https://github.com/eyelock/assistants/commit/e41695c7c61341880ae7985c14c1e71ee8fae23b) Thanks [@eyelock](https://github.com/eyelock)! - Add an `apple-calendar` platform skill and harness. It reads Apple Calendar on a Mac through `che-ical-mcp` (iCloud, Google and Exchange calendars) for unanswered invites, replies pending on invites you organized, clashes, and `catch-up` and `find`. `my-commitments` is not answered there. The server has no read-only mode, so a `before_tool` hook blocks every tool of the server except six calendar read tools; a test pins the hook's pattern against all 29 tools. macOS Calendar access is read and write, so the hook is the only barrier. "Since" is unknown, because the server returns no creation date.

- [#54](https://github.com/eyelock/assistants/pull/54) [`401b88b`](https://github.com/eyelock/assistants/commit/401b88b16e5ab0c00ffa6ce7fa1b2626103b0ab5) Thanks [@eyelock](https://github.com/eyelock)! - A time window now bounds only new asks (mentions, messages, mail). Standing items such as open review requests, assignments and unanswered invites are queried by state with no date filter and show their age. Automated senders collapse into one row per kind, after the people. The GitHub skill documents the `notifications` token scope.

- [#62](https://github.com/eyelock/assistants/pull/62) [`29f247e`](https://github.com/eyelock/assistants/commit/29f247e88b896dc74b342ce5a4690a9dcc167ef8) Thanks [@eyelock](https://github.com/eyelock)! - `find`, `my-commitments` and `add-triage-question` now fire for the requests they were written for: `find` was never used in its own evals because its description did not say it applies to a single small lookup, so it also now says what it adds (where, when, a link, what was searched, and no repeated secrets). `find` rows start with a Where column that names the channel, thread, mail subject or pull request, not only the platform.
