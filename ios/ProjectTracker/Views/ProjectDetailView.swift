import SwiftUI

struct ProjectDetailView: View {
    @EnvironmentObject var store: ProjectStore
    let project: Project

    @State private var showingEditProject = false
    @State private var showingNewTask = false
    @State private var editingTask: ProjectTask?

    private var currentProject: Project {
        store.projects.first(where: { $0.id == project.id }) ?? project
    }

    private var projectTasks: [ProjectTask] { store.tasks(for: project.id) }

    var body: some View {
        List {
            Section {
                LabeledContent("Début", value: currentProject.startDate.formatted(date: .long, time: .omitted))
                LabeledContent("Fin", value: currentProject.endDate.formatted(date: .long, time: .omitted))
                LabeledContent("Durée", value: "\(currentProject.durationInDays) jours")
                if !currentProject.notes.isEmpty {
                    Text(currentProject.notes).foregroundStyle(.secondary)
                }
            }
            Section("Étapes") {
                ForEach(projectTasks) { task in
                    TaskRow(task: task) { newStatus in
                        var updated = task
                        updated.status = newStatus
                        Task { await store.saveTask(updated) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingTask = task }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let task = projectTasks[index]
                        Task { await store.deleteTask(task) }
                    }
                }
                Button {
                    showingNewTask = true
                } label: {
                    Label("Ajouter une étape", systemImage: "plus")
                }
            }
        }
        .navigationTitle(currentProject.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Modifier") { showingEditProject = true }
            }
        }
        .sheet(isPresented: $showingEditProject) {
            ProjectFormView(project: currentProject)
        }
        .sheet(isPresented: $showingNewTask) {
            TaskEditView(projectId: project.id, task: nil, nextOrder: projectTasks.count)
        }
        .sheet(item: $editingTask) { task in
            TaskEditView(projectId: project.id, task: task, nextOrder: task.order)
        }
    }
}

private struct TaskRow: View {
    let task: ProjectTask
    let onStatusChange: (TaskStatus) -> Void

    var body: some View {
        HStack {
            Menu {
                ForEach(TaskStatus.allCases) { status in
                    Button(status.rawValue) { onStatusChange(status) }
                }
            } label: {
                Image(systemName: iconName)
                    .foregroundStyle(color)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            Text(task.name)
            Spacer()
            Text(task.status.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var iconName: String {
        switch task.status {
        case .todo: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .done: return "checkmark.circle.fill"
        }
    }

    private var color: Color {
        switch task.status {
        case .todo: return Color(red: 0.537, green: 0.529, blue: 0.506) // muted, matches status palette
        case .inProgress: return Color(red: 0.980, green: 0.698, blue: 0.098) // warning
        case .done: return Color(red: 0.047, green: 0.639, blue: 0.047) // good
        }
    }
}
