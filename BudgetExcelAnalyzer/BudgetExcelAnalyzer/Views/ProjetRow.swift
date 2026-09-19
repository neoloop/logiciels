import SwiftUI

struct ProjetRow: View {
    let projet: ProjetLine

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(projet.nom)
                    .font(.body.weight(.medium))
                if let articleCode = projet.articleCode, !articleCode.isEmpty {
                    Text(articleCode)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: projet.percentUsed)
                .tint(projet.isOverBudget ? .red : .accentColor)
            HStack {
                Text("Alloué \(projet.budgetAlloue.currencyEUR)")
                Spacer()
                Text("Consommé \(projet.budgetConsomme.currencyEUR)")
                    .foregroundStyle(projet.isOverBudget ? .red : .primary)
                Spacer()
                Text("Reste \(projet.reste.currencyEUR)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
