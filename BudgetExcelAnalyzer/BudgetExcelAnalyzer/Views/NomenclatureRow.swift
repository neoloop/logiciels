import SwiftUI

struct NomenclatureRow: View {
    let summary: NomenclatureSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(summary.articleCode)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text(summary.articleLabel)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
            }
            ProgressView(value: summary.percentEngaged)
                .tint(summary.engagé > summary.voté ? .red : .accentColor)
            HStack {
                Text("Voté \(summary.voté.currencyEUR)")
                Spacer()
                Text("Engagé \(summary.engagé.currencyEUR)")
                    .foregroundStyle(summary.engagé > summary.voté ? .red : .primary)
                Spacer()
                Text("Dispo \(summary.disponible.currencyEUR)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
