import SwiftUI

struct ConsolidatedView: View {
    @EnvironmentObject private var store: BudgetDataStore
    @State private var selectedServiceCode: Int?

    private var nomenclature: [NomenclatureSummary] {
        if let selectedServiceCode {
            store.nomenclature(forService: selectedServiceCode)
        } else {
            store.consolidatedNomenclature
        }
    }
    private var fonctionnement: [NomenclatureSummary] {
        nomenclature.filter { $0.section == .fonctionnement }
    }
    private var investissement: [NomenclatureSummary] {
        nomenclature.filter { $0.section == .investissement }
    }
    private var autre: [NomenclatureSummary] {
        nomenclature.filter { $0.section == .autre }
    }

    var body: some View {
        List {
            Section {
                Picker("Service", selection: $selectedServiceCode) {
                    Text("Tous les services").tag(Int?.none)
                    ForEach(store.services) { service in
                        Text(service.serviceLabel).tag(Int?.some(service.serviceCode))
                    }
                }
                .pickerStyle(.menu)
            }

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
            if nomenclature.isEmpty {
                ContentUnavailableView(
                    "Aucune donnée",
                    systemImage: "tray",
                    description: Text("Importe un classeur pour voir la consolidation.")
                )
            }
        }
    }
}
