---
"@eyelock-assistants/tech-skills": minor
---

Embed learnings from a SwiftUI app audit into `swift-lang` and `swiftui-lang`. `swift-lang` gains rules for `StrictConcurrency=complete` enforcement, picking one async primitive (calling out `Task.sleep` as a race-condition workaround), and `try?` as a regression amplifier. `swiftui-lang` gains the `LoadState`/`isReady` pattern for async stores, `.sheet(item:)` over `.sheet(isPresented:)` to avoid the blank-pill bug, one canonical identity per domain entity, single-source-of-truth `SettingsStore`, codebase-specific test smells (mocks-testing-mocks, type-only assertions, subprocess mocked at the top, missing concurrent-access tests), and a cross-cutting bug-pattern checklist.
