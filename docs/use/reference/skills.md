# Skills

Every skill in the repository, by domain. Each is a `SKILL.md` under `skills/<package>/skills/`
or `plugins/<plugin>/skills/`, following the [agentskills.io](https://agentskills.io/specification)
specification. The line for each is the start of its `description`, which is what an agent reads
to decide whether to load it. Packages and plugins are in [Plugins](plugins.md).

## Development workflow (`skills/dev`, plugin `dev-skills`)

| Skill | What it does |
|---|---|
| `dev-project` | Project setup, directory scaffolding and initial configuration for new software projects. |
| `dev-quality` | Run the full code quality pipeline (lint, format, test, build) with zero tolerance for errors. |
| `dev-review` | Structured code review covering correctness, security, performance and maintainability. |
| `dev-security` | Security-first development: input validation, authentication, secrets, OWASP top 10. |
| `dev-backend` | Backend approach: API design, data flow, error handling and service architecture. |
| `dev-ui` | UI approach: component architecture, state management, accessibility and user experience. |
| `dev-debug` | Debugging a bug that resists fixing: visibility first, a safe local git workflow, pairing with the user. |
| `gh-cli` | GitHub operations via the `gh` CLI, instead of GitHub MCP tools, for PRs, issues, releases and CI. |
| `skill-creator` | Author agent skills that conform to the agentskills.io spec. |

## Gitflow (`plugins/gitflow`)

| Skill | What it does |
|---|---|
| `branching` | The develop/main branching model, branch naming, PR rules and post-merge cleanup. |
| `commits` | Conventional commit format, PR description template and PR title conventions. |
| `quality-gate` | Four gates (build, lint, format, test) that must pass before any commit. |
| `push` | Push committed work, open a PR against the correct base, monitor CI and merge when ready. |
| `release` | Tag-driven release: stable, beta or hotfix, version bump choice, monitoring the workflow. |
| `ci` | GitHub Actions workflows that implement the model: CI gating, branch protection, tag release. |

## Languages (`skills/tech`, plugin `tech-skills`)

| Skill | What it does |
|---|---|
| `go-lang` | Go workflow: Makefile-driven build, test, format, lint and release with strict standards. |
| `java-lang` | Java workflow: build tooling, testing, code style and common patterns. |
| `swift-lang` | Swift 6 and tooling: concurrency, Sendable, actors, async/await, XCTest, `xcodebuild`. |
| `swiftui-lang` | SwiftUI architecture and testing: ViewModel-first extraction, DI, ViewInspector, snapshots. |

## Infrastructure (`skills/infra`, plugin `infra-skills`)

| Skill | What it does |
|---|---|
| `gh-os-repo` | Set up and harden a public GitHub repository: settings, security, branch protection, CI, dependabot. |
| `terraform-backend-aws` | Create an S3 Terraform backend with S3-native state locking, or migrate off DynamoDB locking. |

## Pause (`skills/pause`, plugin `pause-skills`)

| Skill | What it does |
|---|---|
| `help-me-answer` | Guided elicitation for complex questions: one question at a time, conversational. |
| `take-a-moment` | Context checkpoint: trace how we got here and realign perspectives. |

## Writing voice (`skills/voice`, plugin `voice-skills`)

| Skill | What it does |
|---|---|
| `voice` | How voices work: what a voice skill contains, how to write one, how voices compose. |
| `voice-direct` | A plain, brief voice that leads with the answer. The default. |
| `voice-warm` | A friendly voice that acknowledges the person and their effort. |
| `voice-formal` | A careful, complete voice for people outside the team. |
| `reply-styles` | The shape a reply takes on each platform: Slack, GitHub, email, calendar, document comment. |

## Triage (`skills/triage`, plugin `triage-skills`)

| Skill | What it does |
|---|---|
| `waiting-on-me` | What other people have asked of me that I have not done yet. |
| `waiting-on-them` | What I have asked of others that they have not done yet. |
| `action-now-or-soon` | Split what is waiting on me into act now and act soon, with reasons. |
| `my-commitments` | The promises I made in my own words, to whom, when, and whether I did them. |
| `catch-up` | Where one conversation, thread, person or topic stands, in order, with what is open. |
| `find` | Find something said, sent or decided, and say where and when. |
| `triage-report` | The shared rules and table shape for every triage answer, and how to merge platforms. |
| `add-triage-question` | Decide whether a new question belongs on the common list and keep every harness in step. |

## Platforms (`skills/platforms`, plugin `platform-skills`)

How to read one platform well through its MCP server. Used with the triage skills by the
[platform harnesses](harnesses.md).

| Skill | What it does |
|---|---|
| `github` | Read GitHub through the read-only MCP endpoint: reviews, checks, notifications, mentions, issues. |
| `slack` | Read and search Slack through its official MCP server: messages, threads, mentions, DMs. |
| `gmail` | Read Gmail through the Google Workspace MCP server: search, threads, who is waiting on whom. |
| `google-calendar` | Read Calendar: events, invites and responses, recurrence, time zones, clashes. |
| `google-drive` | Read Drive, Docs, Sheets and Slides comments: which are open, answered or addressed to me. |
| `imessage` | Read Messages (iMessage and SMS) on a Mac. Not for sending. |

## Music (`plugins/media-management`)

| Skill | What it does |
|---|---|
| `setup` | Check that the Downloads, Apple Music, NAS and rekordbox paths resolve, and fix any that do not. |
| `select-release` | Find release ZIPs and loose tracks in Downloads and classify them as MP3 or WAV. |
| `process-album` | End to end: extract, verify metadata, import to Apple Music, archive to NAS, clean up. |
| `manage-metadata` | Inspect and update MP3 tags: genre, artist, album, track count, compilation flag. |
| `import-to-apple-music` | Copy finished MP3s into Apple Music through the auto-import folder and verify the album. |
| `archive-media` | Stage a processed release on the NAS: MP3s and WAVs with clean names and a verified count. |
| `cleanup` | Tidy Downloads after a release is processed, after showing the list and confirming. |
| `rip-cd` | Rip a CD securely, verify against AccurateRip, make tagged MP3s and WAVs, import and archive. |
| `audit-release` | Check a release already in Apple Music and repair split albums, titles and artwork in place. |
| `split-long-tracks` | Split tracks over Apple Music's 78-minute limit at quiet points. |
| `reclaim-space` | Free local disk by offloading cloud-backed Apple Music downloads, protecting DJ crates. |

## Vendor harness (`plugins/vendor-harness`)

| Skill | What it does |
|---|---|
| `vendor-adapters` | Cross-vendor reference: support matrix, manifest and marketplace paths, known gaps. |
| `skill-artifact` | Validate and diagnose Agent Skills across Claude Code, Cursor, Codex and Copilot CLI. |
| `subagent-artifact` | Validate and diagnose subagent definitions and their vendor support. |
| `mcp-artifact` | Validate and diagnose MCP server declarations and behaviour. |
| `hooks-artifact` | Validate and diagnose hook configurations and why hooks may not fire. |
| `startup-context` | Validate CLAUDE.md, AGENTS.md, copilot-instructions and rules files. |
| `plugin-audit` | Audit a whole plugin or marketplace for cross-vendor readiness. |
| `fetch-vendor-docs` | Fetch current vendor documentation for comparison with stored references. |
| `flag-vendor-gaps` | Maintain the vendor gap table. |
| `locate-artifact-source` | Find where a harness artifact originated. |
| `compose-feedback` | Compose a structured report for a harness artifact problem. |
| `submit-feedback` | Choose the right channel and submit feedback. |
