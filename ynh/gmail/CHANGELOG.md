# @eyelock-assistants/gmail

## 0.2.0

### Minor Changes

- [#46](https://github.com/eyelock/assistants/pull/46) [`645c494`](https://github.com/eyelock/assistants/commit/645c4949c5f5b0b5ef13a6fb3af9be63acfa507e) Thanks [@eyelock](https://github.com/eyelock)! - Add five read-only platform harnesses (GitHub, Slack, Gmail, Calendar, Drive) that answer what is waiting on you, what you are waiting on, and what to act on now or soon. Add the triage skills they share and the voice and reply-styles skills. Every skill ships evals.

- [#52](https://github.com/eyelock/assistants/pull/52) [`b18b930`](https://github.com/eyelock/assistants/commit/b18b930433c55e6798cb503f250911edd0dd40c4) Thanks [@eyelock](https://github.com/eyelock)! - Add platform-skills, a package of vendor skills (how to work well in one tool through its MCP server): `slack`, `github`, `gmail`, `google-calendar` and `google-drive`. Each platform harness includes its own skill and keeps only what is specific to its server and credentials.

  Breaking: the `calendar` and `drive` harnesses are renamed `google-calendar` and `google-drive`. Anyone who installed the old names must reinstall under the new ones.

- [#60](https://github.com/eyelock/assistants/pull/60) [`183edc7`](https://github.com/eyelock/assistants/commit/183edc7bf7030ca570083eaa96b22bca46a09720) Thanks [@eyelock](https://github.com/eyelock)! - The `gmail` harness answers three more triage questions: `my-commitments`, `catch-up` and `find`. The `gmail` skill says where to look for each.

### Patch Changes

- [#66](https://github.com/eyelock/assistants/pull/66) [`a53c455`](https://github.com/eyelock/assistants/commit/a53c45508ade5ea6e88517b9f54b0d8c0353164a) Thanks [@eyelock](https://github.com/eyelock)! - Pin the Google Workspace MCP server to `workspace-mcp@2.1.0`. Unpinned, `uvx` fetched whatever version was newest each time the harness started, for a server that holds the user's Google OAuth credentials.

- Updated dependencies [[`e41695c`](https://github.com/eyelock/assistants/commit/e41695c7c61341880ae7985c14c1e71ee8fae23b), [`4afa5a5`](https://github.com/eyelock/assistants/commit/4afa5a56f87b4f60cc5fa9cc9bd36d9a889acc49), [`1c21850`](https://github.com/eyelock/assistants/commit/1c21850acf60c4ee0d631f581ea65a1c585a04e7), [`a53c455`](https://github.com/eyelock/assistants/commit/a53c45508ade5ea6e88517b9f54b0d8c0353164a), [`703ed70`](https://github.com/eyelock/assistants/commit/703ed70461c362591cd3b388bff6f6efaf480bf0), [`645c494`](https://github.com/eyelock/assistants/commit/645c4949c5f5b0b5ef13a6fb3af9be63acfa507e), [`b18b930`](https://github.com/eyelock/assistants/commit/b18b930433c55e6798cb503f250911edd0dd40c4), [`24d4db6`](https://github.com/eyelock/assistants/commit/24d4db6de765c95c190f0ed98cd49fbcf7966c6d), [`401b88b`](https://github.com/eyelock/assistants/commit/401b88b16e5ab0c00ffa6ce7fa1b2626103b0ab5), [`29f247e`](https://github.com/eyelock/assistants/commit/29f247e88b896dc74b342ce5a4690a9dcc167ef8), [`23d95fc`](https://github.com/eyelock/assistants/commit/23d95fc2f86875b7913f314f77c0ccbe3a8c3fc9), [`c8d2704`](https://github.com/eyelock/assistants/commit/c8d27045cf2ca1439a5091a29689bcf48428eadd), [`183edc7`](https://github.com/eyelock/assistants/commit/183edc7bf7030ca570083eaa96b22bca46a09720), [`ba67239`](https://github.com/eyelock/assistants/commit/ba67239cb5114cef9f043817aeeb7028f6fbfd02), [`41b5f61`](https://github.com/eyelock/assistants/commit/41b5f61412d2212077df8acec11d4dc74c1ed971), [`8b544e4`](https://github.com/eyelock/assistants/commit/8b544e403c1d861d63ae4c8d29b6fb380376d66f), [`32d58a0`](https://github.com/eyelock/assistants/commit/32d58a05c35dd79dcc09c319f935eb7ca5701d5d)]:
  - @eyelock-assistants/platform-skills@0.2.0
  - @eyelock-assistants/triage-skills@0.2.0
