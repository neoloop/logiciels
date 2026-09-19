import SwiftUI

/// A Sedit order line where the "Service Gestionnaire" (who pays) and "Service
/// Destinataire" (who actually ordered/receives it) differ.
struct CrossServiceOrderRow: View {
    let order: SeditCommandeLine

    private func label(_ code: Int?) -> String {
        guard let code else { return "—" }
        return ServiceDisplayOverrides.displayName(forServiceCode: code, fallback: "Service \(code)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(order.libelle)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Spacer()
                Text(order.montantTTC.currencyEUR)
            }
            HStack(spacing: 4) {
                Text("Budget \(label(order.serviceCode))")
                Image(systemName: "arrow.right")
                Text("Commandé par \(label(order.serviceDestinataire))")
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }
            .font(.caption)
            HStack {
                if let date = order.date {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                }
                Spacer()
                Text("N° \(order.numeroCommande)")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
