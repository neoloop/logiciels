import SwiftUI

struct TaskEditView: View {
    @EnvironmentObject var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    let projectId: String
    let task: ProjectTask?
    let nextOrder: Int

    @State private var name: String
    @State private var status: TaskStatus

    init(projectId: String, task: ProjectTask?, nextOrder: Int) {
        self.projectId = projectId
        self.task = task
        self.nextOrder = nextOrder
        _name = State(initialValue: task?.name ?? "")
        _status = State(initialValue: task?.status ?? .todo)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nom de l'étape", text: $name)
                Picker("Statut", selection: $status) {
                    ForEach(TaskStatus.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            .navigationTitle(task == nil ? "Nouvelle étape" : "Modifier l'étape")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        let saved = ProjectTask(
                            id: task?.id ?? UUID().uuidString,
                            projectId: projectId,
                            name: name,
                            status: status,
                            order: task?.order ?? nextOrder
                        )
                        Task {
                            await store.saveTask(saved)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
