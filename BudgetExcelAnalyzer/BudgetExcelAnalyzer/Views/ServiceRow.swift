import SwiftUI

struct ServiceRow: View {
    let summary: ServiceSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(summary.serviceLabel)
                    .font(.body.weight(.semibold))
                Spacer()
                Text(summary.engagé.currencyEUR)
                    .foregroundStyle(summary.isOverBudget ? .red : .primary)
            }
            ProgressView(value: summary.percentEngaged)
                .tint(summary.isOverBudget ? .red : .accentColor)
            HStack {
                Text("Voté \(summary.voté.currencyEUR)")
                Spacer()
                Text("Disponible \(summary.disponible.currencyEUR)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
