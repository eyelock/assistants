---
name: swiftui-lang
description: SwiftUI architecture and testing — ViewModel-first extraction, protocol-based DI, coverage targets by layer, ViewInspector, snapshot testing, how to safely pass closures to Apple SDK APIs inside @MainActor types, and common anti-patterns.
---

# SwiftUI Architecture & Testing

SwiftUI `View` types are inherently resistant to unit testing — `body` is opaque, state is owned by the framework, and rendering needs a runtime. The solution is not "test the view"; it is to push logic *out* of the view so the view has nothing left to test that isn't a render detail.

## Coverage targets by layer

A healthy SwiftUI app coverage profile:

| Layer | Target line coverage |
|---|---|
| Services (network, disk, process, shell) | **80–95%** |
| ViewModels (`@Observable` / `ObservableObject`) | **80–95%** |
| Pure utility types (parsers, escapers, filters, tokenizers) | **95–100%** |
| Views (SwiftUI `body`, conditionals, small local state) | **10–20%** |
| **Overall** | **60–75%** |

If overall is under 40%, the problem is almost never the View layer — it is uncovered Services and ViewModels masquerading as a View problem. Audit before blaming SwiftUI.

## ViewModel-first architecture

Every screen or sheet has **one** `@Observable` (Swift 5.9+) or `@MainActor ObservableObject` ViewModel that owns all state and logic. The View is a declarative projection.

```swift
@Observable
@MainActor
final class CardEditorViewModel {
    var title: String = ""
    var selectedColumnId: UUID?
    var isSubmitting = false

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func loadFrom(card: Card) { /* ... */ }
    func saveChanges(to card: inout Card) throws { /* ... */ }
}

struct CardEditorView: View {
    @State private var viewModel = CardEditorViewModel()

    var body: some View {
        Form {
            TextField("Title", text: $viewModel.title)
            Button("Save") { try? viewModel.saveChanges(to: &card) }
                .disabled(!viewModel.isValid)
        }
    }
}
```

### Form state vs. presentation state

Not every `@State` needs extraction. Use this discriminator:

- **Form state / business state** → ViewModel. Examples: field values, validation flags, submission state, filter selections, selected IDs, loading flags, error messages.
- **Presentation state** → View. Examples: animation progress, focus ring tracking, hover highlights, disclosure expansion that has no downstream effect.

Rule of thumb: if the same state would need to exist to *test* the behaviour without a View, it belongs in the ViewModel.

### Business state leaking into the View is a regression

Watch for business state that migrated into `@State` *because the ViewModel was untestable*. Example: a set of "deleting IDs" used to drive a spinner — that is business state (lifecycle of a user operation), not presentation state. Move it back to the ViewModel as soon as the ViewModel is testable.

## Pure extraction patterns

Before touching protocols or DI, identify logic that is already pure and just buried inside the wrong file. Extract it to a standalone type in the same module. This is **pure refactoring** — zero behaviour change — and is the highest-ROI step because it unlocks tests without any seam work.

Common categories:

| Category | Extract to | Example types |
|---|---|---|
| URL / query parameter parsing | Struct with getters | `QueryItemExtractor` |
| Filter / sort / search scoring | Stateless struct or `enum` namespace | `CardFilterEngine` |
| String escaping (security-sensitive) | `enum` namespace | `ShellEscaper` |
| Template / token substitution | Struct with `replace(...)` | `InitCommandTokenizer` |
| Line / wire-format parser | `enum Event` + `struct Parser` returning events | `ControlModeLineParser` |
| Alert / dialog builder | `enum` with config struct + `confirm(...)` | `AlertBuilder` |

Signals the logic is ready for extraction:
- It is `private` or `internal` inside a larger type that is hard to instantiate in a test
- It does not touch `self` except to read constants
- A test file would need to redefine the types locally to test it (that is a red flag — the real types are too coupled)

Commit these as `test: extract Xxx to enable ...` — the intent is test-enablement with no production behaviour change.

## Protocol + DI for services

Once pure extraction is exhausted, the remaining untestable code is usually hard-wired to singletons. The fix is a small, repeatable pattern.

### The singleton replacement recipe

1. **Enumerate all call sites** — grep for `X.shared` in the consumer. The *actual* call surface is your protocol; do not invent methods that are not called.
2. **Extract a protocol** covering that minimum surface.
3. **Conform the concrete type** — usually just `extension X: XProtocol {}`.
4. **Inject via init default**:
   ```swift
   init(_ x: any XProtocol = X.shared) {
       self.x = x
   }
   ```
   Production callers using `X.shared` keep working unchanged. Tests inject a mock.
5. **Replace internal uses**: `self.x` instead of `X.shared`.
6. **Write a Mock** in tests: records calls, can throw on demand, holds configurable results.
7. **Commit as `refactor:`** (not `test:`) — this changes the production call path, even if behaviour is identical.

### Persistence singletons are a priority

Persistence singletons (`RepoPersistence`, `YNHPersistence`, anything that writes to `Application Support`) are the single biggest risk. Without DI, tests that create repositories, settings, or harness assignments will write real files — test state leaks into the user's running app. If you ever see fake test data in a running debug build's `.json` files, you need a `PersistenceProtocol` injection before adding another test.

### Circular singleton chains

Watch for `A.shared` → `B.shared` → `A.shared`. Breaking one link often does not unblock tests — the consumer still reaches back through the other side. Before starting, **map the chain end to end** so you know which order of extractions unblocks which tests.

### Document known constraints after each DI pass

One injection rarely unlocks the whole call path. After extracting `TmuxManagerProtocol`, for example, tests may still be blocked by direct `Process()` instantiation or an undocumented `SomeOtherManager.shared` reference deeper in the method. Record these explicitly:

```swift
// TODO: testable after GlobalEnvironmentManager / ProcessRunner DI
```

List them in the plan's "known constraints" section so the next phase has a clear target.

## Testing tools

### ViewInspector (primary for View-level assertions)

[ViewInspector](https://github.com/nalexn/ViewInspector) inspects SwiftUI view trees in `XCTest`. Use it for the residue after ViewModel extraction: "Is this button enabled when `isValid` is false?", "Does this conditional render the error banner?".

Add as a Swift Package dependency. Minimal example:

```swift
import ViewInspector
import XCTest
@testable import MyApp

final class LoginViewTests: XCTestCase {
    func test_submitButton_disabled_whenInvalid() throws {
        let view = LoginView(viewModel: LoginViewModel(email: ""))
        let button = try view.inspect().find(button: "Submit")
        XCTAssertTrue(try button.isDisabled())
    }
}
```

Prefer ViewInspector over snapshot testing for logic assertions — it fails fast with readable diffs, no reference image diffing.

### swift-snapshot-testing (for visual regression)

[PointFree's swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) renders views and diffs against committed reference images or text serializations. Use for:

- Visual regression on layout-critical views (toolbars, sheets, kanban boards)
- Detecting accidental dark/light mode breakage
- Catching `.padding` / `.frame` changes that would otherwise slip through

Do **not** use for logic — image diffs are noisy, slow to iterate on, and don't explain *why* something changed.

### XCTest + Mocks (for Services and ViewModels)

Standard unit tests. ViewModels are `@MainActor`, so test classes that hold them should also be `@MainActor`. Async tests use `async throws` — never `XCTestExpectation` for async/await work.

```swift
@MainActor
final class BoardViewModelTests: XCTestCase {
    func test_deleteCard_updatesColumnCount() async throws {
        let mockPersistence = MockBoardPersistence()
        let vm = BoardViewModel(persistence: mockPersistence)
        try await vm.deleteCard(id: cardID)
        XCTAssertEqual(vm.columns[0].cardCount, expected)
    }
}
```

## Swift 6: closures passed to Apple APIs inside `@MainActor` types

When you are writing a closure argument to an Apple SDK function **inside a `@MainActor` class, struct, or enum**, you must decide whether to mark it `@Sendable` before you finish writing it — not after.

### Why this matters at write time

Swift 6 allows a non-`@Sendable` closure to inherit the actor isolation of its surrounding context. If the surrounding function is `@MainActor`, the closure is inferred as `@MainActor` too. Most Objective-C–origin Apple APIs accept closures without `@Sendable` in their Swift overlay, so they will silently take on your actor's isolation.

The problem: the API calls the closure on a background thread. At runtime, Swift checks the isolation on entry and terminates the app instantly — no alert, no recovery, no log entry visible to the user. The crash is total and silent.

The inner `Task { @MainActor in }` pattern does **not** protect against this. The check fires when the outer closure is entered, before any of its body runs.

### The rule

**Any time you write a closure argument to an Apple SDK API while inside a `@MainActor` context, ask: does this API call my closure on the main thread?**

If you are not certain the answer is yes, add `@Sendable` to the closure.

APIs that are known to call back on background threads (non-exhaustive):

| API | Thread |
|---|---|
| `NSWorkspace.open(_:withApplicationAt:configuration:completionHandler:)` | `com.apple.launchservices.open-queue` |
| `NSWorkspace.open(_:configuration:completionHandler:)` | `com.apple.launchservices.open-queue` |
| `FileHandle.readabilityHandler` | System read queue |
| `Process.terminationHandler` | System process queue |

Any Obj-C–origin completion block not annotated `@Sendable` in the Swift overlay is a candidate. When in doubt, add `@Sendable`.

### How to write it correctly

```swift
@MainActor
enum MyService {
    static func openFile(_ url: URL, handler: URL) {
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([url], withApplicationAt: handler, configuration: config) {
            @Sendable [url] _, error in          // ← always required here
            guard let error else { return }
            Task { @MainActor in
                Self.presentAlert(error: error)  // Self. required — no implicit scope
            }
        }
    }
}
```

```swift
// In a @MainActor class:
pipe.fileHandleForReading.readabilityHandler = { @Sendable [weak self] handle in
    let data = handle.availableData
    Task { @MainActor [weak self] in
        self?.process(data)
    }
}
```

`@Sendable` opts the closure out of actor isolation inheritance. The closure then runs uncontested on whatever thread the API uses, and the `Task { @MainActor in }` hop re-enters the main actor for any state access.

### Already-safe pattern: dispatch queue hop

A closure defined inside `DispatchQueue.global(...).async { }` does not need `@Sendable` on inner callbacks — the dispatch hop is itself `@Sendable` in Swift 6 and breaks the chain. Only closures written *directly* in a `@MainActor` scope need the annotation.

```swift
// Safe — the @Sendable dispatch closure already broke @MainActor inheritance
DispatchQueue.global(qos: .userInitiated).async {
    handle.readabilityHandler = { fh in   // not @MainActor, no annotation needed
        DispatchQueue.main.async { [weak self] in self?.update(fh.availableData) }
    }
}
```

## Async stores need a readiness signal

A store that exposes `items: [T] = []` and flips an `isLoading` flag during refresh leaks a state ambiguity: consumers cannot tell *never loaded* from *loaded empty* from *loading*. Any UI gated on "is there a selected item?" or "is the list non-empty?" will render a wrong empty state during the cold-launch window before `refresh()` resolves. This is a load-bearing class of bug — every new sheet, list, or detail view added against the store inherits it.

Model the lifecycle explicitly:

```swift
enum LoadState<T> {
    case idle           // never loaded
    case loading
    case loaded(T)
    case failed(Error)
}

@Observable
@MainActor
final class HarnessRepository {
    private(set) var state: LoadState<[Harness]> = .idle
    var harnesses: [Harness] { if case .loaded(let xs) = state { return xs } else { return [] } }
    var isReady: Bool { if case .loaded = state { return true } else { return false } }
}
```

Consumers gate on `isReady`, not on `harnesses.isEmpty`. A sheet that depends on a record from the store should not present until `isReady` is true — see the sheet pattern rule below.

## Sheet presentation: prefer `.sheet(item:)` over `.sheet(isPresented:)`

`.sheet(isPresented:)` with a content closure that conditionally renders nothing is a SwiftUI footgun:

```swift
// Footgun — presents an unsized empty view as a tiny white "pill" if the lookup fails
.sheet(isPresented: $showLaunchSheet) {
    if let harness = repo.selectedHarness {
        HarnessLaunchSheet(harness: harness)
    }
}
```

If the lookup returns `nil` (e.g. the store has not finished loading), SwiftUI presents the sheet with an `EmptyView`, which sizes to its intrinsic zero size and renders as a blank rounded rectangle on a dimmed window. The user has no signal that anything is wrong; sometimes a restart "fixes it" because by then the data has loaded.

Use `.sheet(item:)` with an `Identifiable` model. SwiftUI does not present at all while the item is `nil`:

```swift
.sheet(item: $launchTarget) { harness in
    HarnessLaunchSheet(harness: harness)
}
```

Set `launchTarget` only once you know the data is ready (see `isReady` above). Apply this rule project-wide — mixing the two patterns guarantees the next sheet to be added will reproduce the bug.

## One canonical identity per domain entity

When a model type has two equally-valid string forms — `id` vs `name`, namespaced vs bare, slug vs UUID — and different call sites lift different forms off the model, you have an identity seam. Each new consumer (sidebar tag, persisted preference, deep-link URL, log line, exposed API) has roughly a 50/50 chance of picking the wrong form. Fallbacks like `repo.first(where: { $0.id == key || $0.name == key })` paper over the symptom and let the seam keep leaking.

Rules:

- Pick one form as canonical. Almost always: the most-qualified form (`namespace/name`, full UUID).
- Persistence, runtime keys, and view tags all use the canonical form. No exceptions.
- The non-canonical form, if it must exist, is read-only and derived (`harness.shortName` as a computed property).
- New code that lifts a string off a model and passes it across a seam is a review red flag — verify it is the canonical form.

## Settings need a single source of truth

A codebase that reads `UserDefaults.standard.string(forKey:)` from Views, uses `@AppStorage` in other Views, and adds per-instance overrides on top has no owner for the layering. Settings changes do not propagate reliably; overrides drift; tests cannot fake a setting without polluting global state.

Introduce a `SettingsStore` (`@Observable`, `@MainActor`) that owns the read/write surface and the override layering. Views observe the store; tests inject a fake. `@AppStorage` is fine for one-off, non-overridden, view-local toggles — not for any setting that has per-instance overrides or cross-view consumers.

## Testing — smells specific to SwiftUI/Swift codebases

The coverage targets above are necessary but not sufficient. A test suite can hit 70% line coverage and still catch zero release-worthy bugs if the tests are at the wrong boundary. Watch for:

| Smell | What it really means |
|---|---|
| Type-only assertions (`XCTAssertEqual(pane.id, "1")` on a struct you just constructed) | Test passes if the struct compiles — proves nothing |
| Mocks that record call arrays, tests assert the mock recorded a call | You are testing the mock, not the production type |
| Subprocess/system services mocked at the top (`MockYNHDetector` never runs `ynh`) | Cannot detect arg errors, env misconfig, or output-parse drift — the seam where bugs actually live is bypassed |
| `Task.sleep(for: .milliseconds(50))` to "wait for debounce" | CI-load flake risk; use a clock abstraction or signal |
| Codable round-trip tests (encode → decode → compare) | Passes whenever the codec is symmetric, regardless of whether the JSON shape matches what consumers actually emit |
| No test reads a store *while* `isLoading == true` or *before* the first `refresh()` | Async/race coverage is zero — the load-bearing bug class is invisible to the suite |

If recent hotfixes touched integration seams (subprocess, NSWorkspace, Sparkle, FileManager) and no existing test would have caught them, the suite is documenting current behaviour rather than preventing regressions. Add a thin integration-seam protocol (`YNHCommandRunner`, `WorkspaceProvider`, `UpdaterProvider`) and test through it with a fake that can return realistic outputs and errors.

### Concurrent-access tests, not just state-transition tests

Property-state-transition tests (set X, assert Y) do not exercise the cold-launch window. Add tests that:

1. Construct the store
2. Trigger `refresh()` but do **not** await it
3. Read the consumer-facing property and assert the consumer receives a "not ready" signal (not `nil`, not an empty list misinterpreted as "loaded empty")
4. Then await refresh and assert the loaded state

This is the test that would catch an async-readiness regression before it ships.

## Cross-cutting bug patterns to watch for

When a codebase produces repeated late-cycle hotfixes, the patterns are almost always one of three:

1. **Async state read before it is ready** — fix with the `LoadState` / `isReady` pattern above.
2. **Identity ambiguity at a seam** — fix with one canonical form, no fallbacks.
3. **System callback isolation** — closures handed to Apple SDKs from a `@MainActor` scope without `@Sendable`; fix per the rule earlier in this skill, enforced by `StrictConcurrency=complete` (see `swift-lang`).

Symptom-only fixes (another fallback in the lookup, another guard in the consumer) leave the pattern in place and the next instance ships in the next release.

## Anti-patterns and smells

| Smell | What it usually means |
|---|---|
| View file over ~500 lines | Logic is inline — extract a ViewModel and pure types |
| Tests redefining types locally | The real types are too coupled to import — extract pure types |
| Business state (loading flags, selected IDs) in `@State` | ViewModel is untestable or missing — fix the ViewModel, move state back |
| `private init()` on every service | Singleton-only codebase — introduce protocols and DI |
| Fake test data appearing in app-visible `.json` files | Persistence singleton needs protocol + mock injection |
| `@State` properties doing validation | Validation is business logic — move to ViewModel |
| Methods taking 10+ parameters to avoid instantiating a service | Extract the service behind a protocol instead |
| `.sheet(isPresented:)` whose content closure can render nothing | Blank-pill bug waiting to happen — switch to `.sheet(item:)` |
| Store exposes `items: [T] = []` with `isLoading` flag | Conflates never-loaded / loading / loaded-empty — model `LoadState` instead |
| `repo.first(where: { $0.id == key \|\| $0.name == key })` | Identity seam being papered over — pick a canonical form |
| `try?` on git/subprocess/network calls | Loud bugs converted to silent ones — see `swift-lang` |

## Planning structure

Two complementary plan types — keep them separate.

1. **Refactor plan** — structural changes that make code testable. Each phase is a self-contained PR. Commit types: `test:` for pure extract, `refactor:` for protocol/DI introduction. Example phases: extract `QueryItemExtractor`, extract `ShellEscaper`, introduce `GitServiceProtocol`.
2. **Coverage plan** — adds tests to code that is already testable. Commit type: `test:`. Example: "write unit tests for `HarnessSearchService` filtering logic."

Do **not** mix them. A single PR should either restructure code *or* add tests, not both. Mixed PRs are hard to review because you cannot tell whether a change is structural or behavioural.

### Phase discipline

Each phase is one PR into `develop`. A phase is complete when:

1. `make test` passes
2. Build, lint, format-check all pass
3. No observable behaviour changes for users
4. PR is reviewed and merged
5. Next phase rebases on updated `develop` before starting

Use a dedicated worktree for the plan (`.worktrees/test/improve-testability-coverage` etc.) so in-flight work does not disturb the main checkout.

## Order of operations

When attacking a low-coverage SwiftUI codebase, work in this order:

1. **Audit** — split the 0%-coverage files into "no UI dependency" (services, utilities, models) vs. "UI-coupled" (Views, View-hosted logic). The first group is where all the quick wins are.
2. **Services and utilities first** — write tests; no architecture change needed for most.
3. **Pure extractions** — pull parsers, filters, escapers out of big files into their own types. Test the new types. Commit as `test:`.
4. **Protocol + DI** — one service at a time, starting with persistence (highest risk). Commit as `refactor:`, add ViewModel tests using the mock in the next PR.
5. **ViewModel extractions** — for each large View, move form state and business logic to a ViewModel. Test the ViewModel.
6. **ViewInspector residue** — for the thin views that remain, write ViewInspector tests for conditional rendering and button enablement.
7. **Snapshot tests last** — only on visually stable, layout-critical views.

Following this order, the overall coverage number climbs steadily and the biggest jumps come before you ever touch a `body`.
