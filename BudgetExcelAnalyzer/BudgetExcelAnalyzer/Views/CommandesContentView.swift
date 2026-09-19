import SwiftUI

struct CommandesContentView: View {
    @EnvironmentObject private var store: CommandesDataStore
    @EnvironmentObject private var budgetStore: BudgetDataStore
    @Binding var isShowingFilePicker: Bool
    @State private var selectedServiceCode: Int?
    @State private var selectedTab: Tab = .projets

    private enum Tab: String, CaseIterable {
        case projets = "Projets"
        case commandes = "Commandes"
    }

    private var filteredCommandes: [CommandeLine] { store.commandes(forService: selectedServiceCode) }
    private var filteredProjets: [ProjetLine] { store.projets(forService: selectedServiceCode) }

    /// Voté/Dispo per nomenclature for Investissement, cross-referenced from the main budget
    /// file (Situation Budgétaire) and filtered to the same selected service as the projects.
    private var investissementNomenclature: [NomenclatureSummary] {
        let items = selectedServiceCode.map { budgetStore.nomenclature(forService: $0) } ?? budgetStore.consolidatedNomenclature
        return items.filter { $0.section == .investissement }
    }

    var body: some View {
        List {
            Section {
                Picker("Vue", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                if store.serviceCodes.count > 1 {
                    Picker("Service", selection: $selectedServiceCode) {
                        Text("Tous les services").tag(Int?.none)
                        ForEach(store.serviceCodes, id: \.self) { code in
                            Text(store.serviceDisplayName(code)).tag(Int?.some(code))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            switch selectedTab {
            case .projets:
                Section("Projets (\(filteredProjets.count))") {
                    if filteredProjets.isEmpty {
                        Text("Aucun projet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredProjets) { ProjetRow(projet: $0) }
                    }
                }
                if !investissementNomenclature.isEmpty {
                    Section("Budget Investissement — Voté / Dispo") {
                        ForEach(investissementNomenclature) { NomenclatureRow(summary: $0) }
                    }
                }
            case .commandes:
                Section("Commandes (\(filteredCommandes.count))") {
                    if filteredCommandes.isEmpty {
                        Text("Aucune commande")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredCommandes) { CommandeRow(commande: $0) }
                    }
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
