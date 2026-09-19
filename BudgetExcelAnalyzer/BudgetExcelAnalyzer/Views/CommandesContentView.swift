import SwiftUI

struct CommandesContentView: View {
    @EnvironmentObject private var store: CommandesDataStore
    @Binding var isShowingFilePicker: Bool
    @State private var selectedServiceCode: Int?

    private var filteredCommandes: [CommandeLine] { store.commandes(forService: selectedServiceCode) }
    private var filteredProjets: [ProjetLine] { store.projets(forService: selectedServiceCode) }

    var body: some View {
        List {
            if store.serviceCodes.count > 1 {
                Section {
                    Picker("Service", selection: $selectedServiceCode) {
                        Text("Tous les services").tag(Int?.none)
                        ForEach(store.serviceCodes, id: \.self) { code in
                            Text(store.serviceDisplayName(code)).tag(Int?.some(code))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Section("Projets") {
                if filteredProjets.isEmpty {
                    Text("Aucun projet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredProjets) { ProjetRow(projet: $0) }
                }
            }

            Section("Commandes (\(filteredCommandes.count))") {
                if filteredCommandes.isEmpty {
                    Text("Aucune commande")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredCommandes) { CommandeRow(commande: $0) }
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
