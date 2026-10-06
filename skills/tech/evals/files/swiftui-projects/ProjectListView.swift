import SwiftUI

struct ProjectListView: View {
    @State private var repo = ProjectRepository.shared
    @AppStorage("lastOpenedProject") private var lastOpenedProject = ""
    @State private var showDetailSheet = false
    @State private var archivingIDs: Set<String> = []
    @State private var search = ""

    var body: some View {
        List(filtered) { project in
            HStack {
                Text(project.name)
                Spacer()
                if archivingIDs.contains(project.id) {
                    ProgressView()
                }
                Button("Archive") {
                    archivingIDs.insert(project.id)
                    Task {
                        try? await repo.archive(project)
                        archivingIDs.remove(project.id)
                    }
                }
            }
            .onTapGesture {
                lastOpenedProject = project.name
                showDetailSheet = true
            }
        }
        .searchable(text: $search)
        .task {
            await repo.refresh()
            if !lastOpenedProject.isEmpty {
                showDetailSheet = true
            }
        }
        .sheet(isPresented: $showDetailSheet) {
            if let project = repo.project(for: lastOpenedProject) {
                ProjectDetailSheet(project: project)
            }
        }
    }

    private var filtered: [Project] {
        let term = search.lowercased().trimmingCharacters(in: .whitespaces)
        return repo.projects
            .filter { !$0.archived }
            .filter { term.isEmpty || $0.name.lowercased().contains(term) }
            .sorted { $0.name < $1.name }
    }
}
