import SwiftUI
import SwiftData

struct DiveListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Dive.date, order: .reverse) private var dives: [Dive]
    @State private var isPresentingNewDive = false

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
                        ForEach(dives) { dive in
                            NavigationLink(value: dive) {
                                DiveRowView(dive: dive)
                            }
                        }
                        .onDelete(perform: deleteDives)
                    }
                }
            }
            .navigationTitle("Plongées")
            .navigationDestination(for: Dive.self) { dive in
                DiveDetailView(dive: dive)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresentingNewDive = true
                    } label: {
                        Label("Ajouter", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewDive) {
                NavigationStack {
                    DiveFormView(dive: nil)
                }
            }
        }
    }

    private func deleteDives(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(dives[index])
        }
    }
}

#Preview {
    DiveListView()
        .modelContainer(for: Dive.self, inMemory: true)
}
