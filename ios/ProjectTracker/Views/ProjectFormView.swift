import SwiftUI

struct ProjectFormView: View {
    @EnvironmentObject var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    let project: Project?

    @State private var name: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var notes: String

    init(project: Project?) {
        self.project = project
        _name = State(initialValue: project?.name ?? "")
        _startDate = State(initialValue: project?.startDate ?? .now)
        _endDate = State(initialValue: project?.endDate ?? .now)
        _notes = State(initialValue: project?.notes ?? "")
    }

    private var durationPreview: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(days + 1, 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Nom du projet", text: $name)
                    DatePicker("Date de début", selection: $startDate, displayedComponents: .date)
                    DatePicker("Date de fin", selection: $endDate, in: startDate..., displayedComponents: .date)
                    LabeledContent("Durée") {
                        Text("\(durationPreview) jour\(durationPreview > 1 ? "s" : "")")
                    }
                }
                Section("Notes") {
                    TextEditor(text: $notes).frame(minHeight: 80)
                }
            }
            .navigationTitle(project == nil ? "Nouveau projet" : "Modifier le projet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        let saved = Project(
                            id: project?.id ?? UUID().uuidString,
                            name: name,
                            startDate: startDate,
                            endDate: endDate,
                            notes: notes
                        )
                        Task {
                            await store.saveProject(saved)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
