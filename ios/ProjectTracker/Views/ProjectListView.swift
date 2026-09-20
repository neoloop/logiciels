import SwiftUI

struct ProjectListView: View {
    @EnvironmentObject var store: ProjectStore
    @State private var showingNewProject = false

    var body: some View {
        List {
            ForEach(store.projects) { project in
                NavigationLink(value: project) {
                    ProjectRow(project: project)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let project = store.projects[index]
                    Task { await store.deleteProject(project) }
                }
            }
        }
        .navigationTitle("Projets")
        .navigationDestination(for: Project.self) { project in
            ProjectDetailView(project: project)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingNewProject = true } label: { Image(systemName: "plus") }
            }
        }
        .refreshable { await store.refresh() }
        .sheet(isPresented: $showingNewProject) {
            ProjectFormView(project: nil)
        }
        .overlay {
            if store.isSyncing && store.projects.isEmpty {
                ProgressView("Synchronisation…")
            } else if store.projects.isEmpty {
                ContentUnavailableView(
                    "Aucun projet",
                    systemImage: "tray",
                    description: Text("Ajoutez votre premier projet avec le bouton +")
                )
            }
        }
    }
}

private struct ProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.name).font(.headline)
            Text("\(project.startDate.formatted(date: .abbreviated, time: .omitted)) → \(project.endDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(project.durationInDays) jour\(project.durationInDays > 1 ? "s" : "")")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
