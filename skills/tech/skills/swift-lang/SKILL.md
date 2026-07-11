---
name: swift-lang
description: Swift 6 language and tooling — concurrency model, Sendable, actors, XCTest basics, and xcodebuild. For SwiftUI architecture and view-layer testing, see `swiftui-lang`.
---

# Swift Development

For SwiftUI-specific architecture (ViewModel extraction, DI, ViewInspector, snapshot testing, coverage targets by layer), load the `swiftui-lang` skill.

## Swift 6 Concurrency

Swift 6 enforces data isolation at compile time. Every type must be either `Sendable` or confined to an actor.

**Actors** isolate mutable state:
```swift
actor MyService {
    private var cache: [String: Data] = [:]

    func fetch(key: String) async -> Data? {
        cache[key]
    }
}
```

**`@MainActor`** for UI-bound types:
```swift
@MainActor
final class ViewModel: ObservableObject {
    var items: [Item] = []
}
```

**`Sendable`** for types crossing actor boundaries — must be value types or immutable:
```swift
struct Config: Sendable {
    let baseURL: URL
    let timeout: TimeInterval
}
```

**Rules:**
- Prefer value types (`struct`) over reference types (`class`) for `Sendable` conformance
- Mark `@Observable` types as `@MainActor` when they drive UI
- Use `async/await` — avoid `DispatchQueue` and callback chains
- Never use `nonisolated(unsafe)` without a clear documented reason

### Enforce strict concurrency at compile time

Manual review cannot catch every missed `@Sendable` on a closure handed to an Apple SDK that dispatches on a background queue. The only durable enforcement is the build flag:

```swift
// Package.swift
.target(
    name: "App",
    swiftSettings: [.enableExperimentalFeature("StrictConcurrency=complete")]
)
```

Until the project compiles cleanly under `StrictConcurrency=complete`, treat every closure literal written inside a `@MainActor` scope as a latent EXC_BREAKPOINT — see `swiftui-lang` for the per-call-site rule.

### Pick one async primitive

`DispatchQueue.main.asyncAfter`, `Task.sleep(nanoseconds:)`, `Timer.scheduledTimer`, and bare GCD coexisting in the same codebase is a smell. Default to `async/await`; reach for `Timer` only for periodic UI ticks. New code should not introduce GCD.

`Task.sleep` used to wait for "something to be ready" (connect, callback drain, settle) is a race-condition workaround, not coordination. It will go flaky under load and mask the next race. Replace with an explicit signal: a continuation, an `AsyncStream`, or a state observer.

## Error handling — `try?` is a regression amplifier

`try?` converts loud failures into silent ones. The user sees "nothing happened" and there is nothing to debug. Reserve it for cases where the failure genuinely has no consequence (e.g. best-effort cache prime). For anything user-visible — git, subprocess, filesystem, network — surface the error:

```swift
// Bad — silent
let branches = try? await git.listBranches()

// Good — log and propagate or present
do {
    let branches = try await git.listBranches()
    ...
} catch {
    logger.error("git listBranches failed: \(error)")
    throw error  // or surface to the user
}
```

## Testing with XCTest

```swift
final class MyServiceTests: XCTestCase {
    func testFetchReturnsExpectedValue() async throws {
        let service = MyService()
        let result = try await service.fetch("key")
        XCTAssertEqual(result, expectedValue)
    }
}
```

**Rules:**
- Test names describe the scenario: `test<Subject>_<Condition>_<ExpectedResult>`
- Async tests use `async throws` — no `XCTestExpectation` for async work
- Use `setUp()` / `tearDown()` for shared state, not instance properties
- Test at the unit boundary — mock only at system edges (network, filesystem)

## xcodebuild Tooling

Prefer `make` targets over direct `xcodebuild` invocations. Projects expose:

```bash
make build         # xcodebuild build
make test          # xcodebuild test
make lint          # SwiftLint
make format        # SwiftFormat (fix)
make format-check  # SwiftFormat (check only, for CI)
make check         # build + lint + format-check + test
```

Running directly when needed:
```bash
xcodebuild build -scheme MyApp -destination 'platform=macOS'
xcodebuild test  -scheme MyApp -destination 'platform=macOS'
```

## Code Signing (macOS)

- Debug builds: automatic signing, any team
- Release/distribution builds: specific team ID, provisioning profile
- Notarization required for distribution outside the App Store
- Entitlements (`*.entitlements`) must match capabilities declared in the target

Never hardcode signing identity strings — use `CODE_SIGN_IDENTITY=` with build setting variables.
