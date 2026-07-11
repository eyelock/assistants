# @eyelock-assistants/tech-skills

## 0.2.0

### Minor Changes

- [#17](https://github.com/eyelock/assistants/pull/17) [`1d837bc`](https://github.com/eyelock/assistants/commit/1d837bca0b5562a5b24a507c72f69cb7666e58c9) Thanks [@eyelock](https://github.com/eyelock)! - Embed learnings from a SwiftUI app audit into `swift-lang` and `swiftui-lang`. `swift-lang` gains rules for `StrictConcurrency=complete` enforcement, picking one async primitive (calling out `Task.sleep` as a race-condition workaround), and `try?` as a regression amplifier. `swiftui-lang` gains the `LoadState`/`isReady` pattern for async stores, `.sheet(item:)` over `.sheet(isPresented:)` to avoid the blank-pill bug, one canonical identity per domain entity, single-source-of-truth `SettingsStore`, codebase-specific test smells (mocks-testing-mocks, type-only assertions, subprocess mocked at the top, missing concurrent-access tests), and a cross-cutting bug-pattern checklist.

- [#13](https://github.com/eyelock/assistants/pull/13) [`173aa3b`](https://github.com/eyelock/assistants/commit/173aa3b8e77e4074a78360dda46f7576e06427b4) Thanks [@eyelock](https://github.com/eyelock)! - Split `swift-lang` into `swift-lang` (Swift 6 concurrency, XCTest, xcodebuild, code signing) and `swiftui-lang` (ViewModel-first architecture, DI, ViewInspector, snapshot testing, `@MainActor`/`@Sendable` closure safety with Apple SDK APIs).
