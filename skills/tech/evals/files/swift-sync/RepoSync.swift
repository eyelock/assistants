import Foundation
import os

protocol GitClient: Sendable {
    func connect() async throws
    func listBranches() async throws -> [String]
    func pull(branch: String) async throws
}

/// Shared by the menu bar item and the CLI, which call it from different tasks.
final class BranchCache {
    var branches: [String] = []
    var lastRefresh: Date?

    func replace(with names: [String]) {
        branches = names
        lastRefresh = Date()
    }
}

nonisolated(unsafe) var sharedCache = BranchCache()

/// Keeps the local branch list in step with the remote. The menu bar item and the CLI both use it.
@MainActor
final class RepoSync {
    private(set) var branches: [String] = []
    private(set) var status = ""

    private let git: GitClient
    private let logger = Logger(subsystem: "com.example.reposync", category: "git")

    init(git: GitClient) {
        self.git = git
    }

    func load() async {
        Task { try? await git.connect() }
        // Give the connection a moment to come up before listing.
        try? await Task.sleep(nanoseconds: 300_000_000)
        let names = (try? await git.listBranches()) ?? []
        sharedCache.replace(with: names)
        branches = names
    }

    func pull(_ branch: String) {
        Task {
            try? await git.pull(branch: branch)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.status = "Pulled \(branch)"
            }
        }
    }
}
