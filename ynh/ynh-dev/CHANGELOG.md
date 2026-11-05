# @eyelock-assistants/ynh-dev

## 0.3.1

### Patch Changes

- [#135](https://github.com/eyelock/assistants/pull/135) [`c80cdfc`](https://github.com/eyelock/assistants/commit/c80cdfc35f81d3d901084d5a85751dabbadccfb9) Thanks [@eyelock](https://github.com/eyelock)! - The manifest sync now finds a ynh harness's manifest in `.agents/harness/`, so version writeback and the drift check cover every ynh harness. The manifests of these four had fallen behind their packages and now match them.

- [#102](https://github.com/eyelock/assistants/pull/102) [`4ad9470`](https://github.com/eyelock/assistants/commit/4ad94700e434722854ce90cb9d817d464dfc3413) Thanks [@eyelock](https://github.com/eyelock)! - The `ynh-dev` harness swaps its unpinned `golang-pro` include from `Jeffallan/claude-skills`, which scans with 2 active SkillSpector findings, for `golang-patterns` and `golang-testing` from `affaan-m/everything-claude-code`, pinned to a full commit SHA and scanning with 0 active findings. `ynh/ynh-dev/pinned-skills.md` records the publisher, licence, the files read, the scan result and the candidates rejected.

  The harness gains an `AGENTS.md` saying that `go-lang` and the repository's own conventions win wherever the two new skills disagree with them.

  The include sets `"instructions": false`, so only the two `SKILL.md` files reach the harness and not the repository's root `AGENTS.md`.

- Updated dependencies [[`1086997`](https://github.com/eyelock/assistants/commit/1086997ce2ecb7e6233c39f44fd94f83db41f57b), [`c3f171c`](https://github.com/eyelock/assistants/commit/c3f171cb7488dc42188d8d53dd9d9bad6ff9b33e), [`ae48602`](https://github.com/eyelock/assistants/commit/ae486026d5f987201a3d286bef5b4b0fa467eb71), [`0ea045b`](https://github.com/eyelock/assistants/commit/0ea045b2cf3cf4dcbdf46e3c99edc32f07737168)]:
  - @eyelock-assistants/dev-skills@0.2.0
  - @eyelock-assistants/gitflow@0.3.0
  - @eyelock-assistants/tech-skills@0.2.1
  - @eyelock-assistants/pause-skills@0.1.1

## 0.3.0

### Minor Changes

- [#18](https://github.com/eyelock/assistants/pull/18) [`8695f9b`](https://github.com/eyelock/assistants/commit/8695f9bd380172abea9f6e11a015c639a70a28e9) Thanks [@eyelock](https://github.com/eyelock)! - Add `profiles` and `focuses` to `ynh-dev` and `termq-dev` sample harnesses. `ynh-dev` gains five Go-specific focuses (code-review, security-hardening, cli-contract, refactor, changelog) and a math-olympiad include; `termq-dev` gains five Swift/SwiftUI focuses (code-review, security-audit, refactor, pr-summary, changelog).

### Patch Changes

- Updated dependencies [[`1d837bc`](https://github.com/eyelock/assistants/commit/1d837bca0b5562a5b24a507c72f69cb7666e58c9), [`173aa3b`](https://github.com/eyelock/assistants/commit/173aa3b8e77e4074a78360dda46f7576e06427b4)]:
  - @eyelock-assistants/tech-skills@0.2.0

## 0.2.0

### Patch Changes

- Updated dependencies [[`1244331`](https://github.com/eyelock/assistants/commit/1244331b17109af897b509f19c0306ef5d751fd4)]:
  - @eyelock-assistants/gitflow@0.2.0
