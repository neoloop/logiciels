import SwiftUI

struct ConsolidatedView: View {
    @EnvironmentObject private var store: BudgetDataStore

    private var fonctionnement: [NomenclatureSummary] {
        store.consolidatedNomenclature.filter { $0.section == .fonctionnement }
    }
    private var investissement: [NomenclatureSummary] {
        store.consolidatedNomenclature.filter { $0.section == .investissement }
    }
    private var autre: [NomenclatureSummary] {
        store.consolidatedNomenclature.filter { $0.section == .autre }
    }

    var body: some View {
        List {
            if !fonctionnement.isEmpty {
                Section("Fonctionnement") {
                    ForEach(fonctionnement) { NomenclatureRow(summary: $0) }
                }
            }
            if !investissement.isEmpty {
                Section("Investissement") {
                    ForEach(investissement) { NomenclatureRow(summary: $0) }
                }
            }
            if !autre.isEmpty {
                Section("Autre") {
                    ForEach(autre) { NomenclatureRow(summary: $0) }
                }
            }
        }
        .navigationTitle("Consolidation")
        .overlay {
            if store.consolidatedNomenclature.isEmpty {
                ContentUnavailableView(
                    "Aucune donnée",
                    systemImage: "tray",
                    description: Text("Importe un classeur pour voir la consolidation.")
                )
            }
        }
    }
}
