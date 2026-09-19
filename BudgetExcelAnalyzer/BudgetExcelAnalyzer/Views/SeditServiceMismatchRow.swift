import SwiftUI

/// A Sedit order line where two of its service fields disagree (e.g. "Service
/// Gestionnaire" vs "Service Destinataire", or "Service émetteur" vs "Service de
/// facturation"). Generic so both mismatch types share one row.
struct SeditServiceMismatchRow: View {
    let order: SeditCommandeLine
    let fromCode: Int?
    let fromLabel: String
    let toCode: Int?
    let toLabel: String

    private func serviceName(_ code: Int?) -> String {
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
                Text("\(fromLabel) \(serviceName(fromCode))")
                Image(systemName: "arrow.right")
                Text("\(toLabel) \(serviceName(toCode))")
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
