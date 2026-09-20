import SwiftUI
import SwiftData

struct ImportProgramView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var rawText: String = ""
    @State private var parsedEntries: [ParsedProgramEntry] = []
    @State private var hasAnalyzed = false

    private var includedCount: Int {
        parsedEntries.filter(\.isIncluded).count
    }

    var body: some View {
        Form {
            Section("Coller le message du programme") {
                TextEditor(text: $rawText)
                    .frame(minHeight: 150)
                Button("Analyser le texte") {
                    parsedEntries = ProgramTextParser.parse(rawText)
                    hasAnalyzed = true
                }
                .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if hasAnalyzed {
                Section("Plongées détectées (\(includedCount)/\(parsedEntries.count))") {
                    if parsedEntries.isEmpty {
                        Text("Aucun créneau reconnu. Le message doit contenir des lignes commençant par un jour (Lundi, Mardi…).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach($parsedEntries) { $entry in
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle(isOn: $entry.isIncluded) {
                                    TextField("Lieu", text: $entry.siteName)
                                        .font(.body.weight(.medium))
                                }
                                DatePicker(
                                    "Date et heure",
                                    selection: $entry.dateTime,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                Text(entry.rawLine)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 4)
                            .opacity(entry.isIncluded ? 1 : 0.4)
                        }
                    }
                }
            }
        }
        .navigationTitle("Importer un programme")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Ajouter (\(includedCount))") {
                    createDives()
                }
                .disabled(includedCount == 0)
            }
        }
    }

    private func createDives() {
        for entry in parsedEntries where entry.isIncluded {
            let dive = Dive(date: entry.dateTime, locationName: entry.siteName, status: .planned)
            modelContext.insert(dive)
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ImportProgramView()
    }
    .modelContainer(for: Dive.self, inMemory: true)
}
