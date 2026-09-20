import SwiftUI
import SwiftData

struct DiveListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Dive.date, order: .reverse) private var dives: [Dive]
    @State private var isPresentingNewDive = false
    @State private var isPresentingImport = false

    private var upcomingDives: [Dive] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: startOfToday) else {
            return []
        }
        return dives
            .filter { $0.status == .planned && $0.date >= startOfToday && $0.date < weekEnd }
            .sorted { $0.date < $1.date }
    }

    private var completedDives: [Dive] {
        dives
            .filter { $0.status == .completed }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if dives.isEmpty {
                    ContentUnavailableView(
                        "Aucune plongée",
                        systemImage: "water.waves",
                        description: Text("Ajoutez votre première plongée avec le bouton +")
                    )
                } else {
                    List {
                        if !upcomingDives.isEmpty {
                            Section("Programme de la semaine") {
                                ForEach(upcomingDives) { dive in
                                    NavigationLink(value: dive) {
                                        DiveRowView(dive: dive)
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            markAsCompleted(dive)
                                        } label: {
                                            Label("Réalisée", systemImage: "checkmark")
                                        }
                                        .tint(.green)
                                    }
                                }
                                .onDelete { offsets in
                                    deleteDives(upcomingDives, at: offsets)
                                }
                            }
                        }

                        Section("Historique") {
                            if completedDives.isEmpty {
                                Text("Aucune plongée réalisée pour le moment")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(completedDives) { dive in
                                    NavigationLink(value: dive) {
                                        DiveRowView(dive: dive)
                                    }
                                }
                                .onDelete { offsets in
                                    deleteDives(completedDives, at: offsets)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Plongées")
            .navigationDestination(for: Dive.self) { dive in
                DiveDetailView(dive: dive)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            isPresentingNewDive = true
                        } label: {
                            Label("Nouvelle plongée", systemImage: "plus")
                        }
                        Button {
                            isPresentingImport = true
                        } label: {
                            Label("Importer un programme", systemImage: "text.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewDive) {
                NavigationStack {
                    DiveFormView(dive: nil)
                }
            }
            .sheet(isPresented: $isPresentingImport) {
                NavigationStack {
                    ImportProgramView()
                }
            }
        }
    }

    private func deleteDives(_ source: [Dive], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(source[index])
        }
    }

    private func markAsCompleted(_ dive: Dive) {
        dive.status = .completed
    }
}

#Preview {
    DiveListView()
        .modelContainer(for: Dive.self, inMemory: true)
}
