import SwiftUI

struct TransactionListView: View {
    @EnvironmentObject private var store: BudgetDataStore
    let category: String
    let month: Date

    private var transactions: [Transaction] {
        let calendar = Calendar.current
        return store.transactions
            .filter { $0.category == category && calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List(transactions) { transaction in
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(transaction.date, format: .dateTime.day().month().year())
                    Spacer()
                    Text(transaction.amount, format: .currency(code: "EUR"))
                }
                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(category)
        .overlay {
            if transactions.isEmpty {
                ContentUnavailableView(
                    "Aucune transaction",
                    systemImage: "tray",
                    description: Text("Pas de mouvement pour cette catégorie sur le mois sélectionné.")
                )
            }
        }
    }
}
