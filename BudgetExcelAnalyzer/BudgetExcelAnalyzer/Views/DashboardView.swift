import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: BudgetDataStore
    @Binding var isShowingFilePicker: Bool

    var body: some View {
        List {
            Section("Services") {
                ForEach(store.services) { service in
                    NavigationLink {
                        ServiceDetailView(service: service)
                    } label: {
                        ServiceRow(summary: service)
                    }
                }
            }

            Section("Consolidation") {
                NavigationLink("Toutes nomenclatures, tous services") {
                    ConsolidatedView()
                }
            }

            if let lastImportDate = store.lastImportDate {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        if let name = store.sourceFileName {
                            Text(name).font(.caption).foregroundStyle(.secondary)
                        }
                        Text("Importé le \(lastImportDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .refreshable {
            await store.refreshFromSavedBookmark()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingFilePicker = true
                } label: {
                    Label("Importer", systemImage: "square.and.arrow.down")
                }
            }
        }
    }
}
