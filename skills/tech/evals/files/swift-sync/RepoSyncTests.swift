import XCTest
@testable import RepoSyncKit

final class RepoSyncTests: XCTestCase {
    let git = FakeGitClient(branches: ["main", "develop"])

    @MainActor
    func testLoad() {
        let model = RepoSync(git: git)
        let done = expectation(description: "loaded")
        Task {
            await model.load()
            done.fulfill()
        }
        wait(for: [done], timeout: 2)
        XCTAssertEqual(model.branches, ["main", "develop"])
    }

    @MainActor
    func testPull() async {
        let model = RepoSync(git: git)
        model.pull("main")
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        XCTAssertEqual(model.status, "Pulled main")
    }
}
