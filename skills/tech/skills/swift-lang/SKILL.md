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
