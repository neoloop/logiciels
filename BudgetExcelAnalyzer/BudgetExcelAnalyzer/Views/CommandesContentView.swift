import SwiftUI

struct CommandesContentView: View {
    @EnvironmentObject private var store: CommandesDataStore
    @EnvironmentObject private var budgetStore: BudgetDataStore
    @EnvironmentObject private var seditStore: SeditDataStore
    @Binding var isShowingFilePicker: Bool
    @State private var isShowingSeditFilePicker = false
    @State private var selectedServiceCode: Int?
    @State private var selectedTab: Tab = .projets

    private enum Tab: String, CaseIterable {
        case projets = "Projets"
        case commandes = "Commandes"
        case ecarts = "Écarts BC"
    }

    private var filteredCommandes: [CommandeLine] { store.commandes(forService: selectedServiceCode) }
    private var filteredProjets: [ProjetLine] { store.projets(forService: selectedServiceCode) }

    /// Voté/Dispo per nomenclature for Investissement, cross-referenced from the main budget
    /// file (Situation Budgétaire) and filtered to the same selected service as the projects.
    private var investissementNomenclature: [NomenclatureSummary] {
        let items = selectedServiceCode.map { budgetStore.nomenclature(forService: $0) } ?? budgetStore.consolidatedNomenclature
        return items.filter { $0.section == .investissement }
    }

    private func filteredByService(_ items: [BCDiscrepancy]) -> [BCDiscrepancy] {
        guard let selectedServiceCode else { return items }
        return items.filter { $0.serviceCode == selectedServiceCode }
    }

    private var missingFromExpression: [BCDiscrepancy] {
        filteredByService(BCReconciliation.inSeditNotExpression(sedit: seditStore.commandes, expression: store.commandes(forService: nil)))
    }
    private var missingFromSedit: [BCDiscrepancy] {
        filteredByService(BCReconciliation.inExpressionNotSedit(expression: store.commandes(forService: nil), sedit: seditStore.commandes))
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
            case .ecarts:
                if seditStore.commandes.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Compare le fichier Sedit avec Expression")
                                .font(.headline)
                            Text("Importe l'export Sedit (.xlsx) pour voir les commandes qui ne se retrouvent pas dans les deux fichiers, rapprochées par numéro de BC.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button {
                                isShowingSeditFilePicker = true
                            } label: {
                                Label("Choisir le fichier Sedit", systemImage: "folder")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Section("Dans Sedit, pas dans Expression (\(missingFromExpression.count))") {
                        if missingFromExpression.isEmpty {
                            Text("Aucun écart")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(missingFromExpression) { BCDiscrepancyRow(discrepancy: $0) }
                        }
                    }
                    Section("Dans Expression, pas dans Sedit (\(missingFromSedit.count))") {
                        if missingFromSedit.isEmpty {
                            Text("Aucun écart")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(missingFromSedit) { BCDiscrepancyRow(discrepancy: $0) }
                        }
                    }
                    Section {
                        Button {
                            isShowingSeditFilePicker = true
                        } label: {
                            Label("Réimporter le fichier Sedit", systemImage: "arrow.clockwise")
                        }
                        if let lastImportDate = seditStore.lastImportDate {
                            VStack(alignment: .leading, spacing: 4) {
                                if let name = seditStore.sourceFileName {
                                    Text(name).font(.caption).foregroundStyle(.secondary)
                                }
                                Text("Importé le \(lastImportDate.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if selectedTab != .ecarts, let lastImportDate = store.lastImportDate {
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
            await seditStore.refreshFromSavedBookmark()
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
        .fileImporter(
            isPresented: $isShowingSeditFilePicker,
            allowedContentTypes: [.excelWorkbook, .xlsxExtension, .legacyExcelWorkbook, .xlsExtension],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task { await seditStore.importFile(from: url) }
                }
            case .failure(let error):
                seditStore.errorMessage = error.localizedDescription
            }
        }
        .overlay {
            if seditStore.isImporting {
                ProgressView("Lecture du fichier Sedit…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert(
            "Erreur Sedit",
            isPresented: Binding(
                get: { seditStore.errorMessage != nil },
                set: { if !$0 { seditStore.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(seditStore.errorMessage ?? "")
        }
    }
}
