import Foundation
import Observation

struct Project: Identifiable, Hashable, Codable {
    let id: String      // "team/name"
    let name: String    // "name"
    var archived: Bool
}

@Observable
@MainActor
final class ProjectRepository {
    static let shared = ProjectRepository()

    var projects: [Project] = []
    var isLoading = false

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        projects = (try? await ProjectAPI.shared.fetchProjects()) ?? []
    }

    func project(for key: String) -> Project? {
        projects.first(where: { $0.id == key || $0.name == key })
    }

    func archive(_ project: Project) async throws {
        try await ProjectAPI.shared.archive(id: project.id)
        await refresh()
    }
}
