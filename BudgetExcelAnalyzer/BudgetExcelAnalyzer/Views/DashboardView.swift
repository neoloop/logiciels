import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: BudgetDataStore
    @Binding var isShowingFilePicker: Bool

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }

    var body: some View {
        List {
            Section {
                if store.availableMonths.count > 1 {
                    Picker("Mois", selection: $store.selectedMonth) {
                        ForEach(store.availableMonths, id: \.self) { month in
                            Text(monthFormatter.string(from: month).capitalized).tag(month)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(store.totalActual, format: .currency(code: "EUR"))
                            .font(.headline)
                            .foregroundStyle(store.totalActual > store.totalBudget ? .red : .primary)
                        if store.totalBudget > 0 {
                            Text("sur \(store.totalBudget, format: .currency(code: "EUR"))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Par catégorie") {
                ForEach(store.categorySummaries) { summary in
                    NavigationLink {
                        TransactionListView(category: summary.category, month: store.selectedMonth)
                    } label: {
                        CategoryRow(summary: summary)
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
