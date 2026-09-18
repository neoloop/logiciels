import SwiftUI

struct CategoryRow: View {
    let summary: CategorySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(summary.category)
                    .font(.body.weight(.medium))
                Spacer()
                Text(summary.actual, format: .currency(code: "EUR"))
                    .foregroundStyle(summary.isOverBudget ? .red : .primary)
            }

            if let budget = summary.budget {
                ProgressView(value: min(summary.progress ?? 0, 1))
                    .tint(summary.isOverBudget ? .red : .accentColor)
                HStack {
                    Text("Budget : \(budget, format: .currency(code: "EUR"))")
                    Spacer()
                    if let remaining = summary.remaining {
                        Text(
                            remaining >= 0
                                ? "Reste \(remaining, format: .currency(code: "EUR"))"
                                : "Dépassement \(abs(remaining), format: .currency(code: "EUR"))"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text("Hors budget")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}
