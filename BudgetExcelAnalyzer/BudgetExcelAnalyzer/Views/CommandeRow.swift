import SwiftUI

struct CommandeRow: View {
    let commande: CommandeLine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(commande.libelle)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Spacer()
                Text(commande.montant.currencyEUR)
            }
            HStack(spacing: 4) {
                if let articleCode = commande.articleCode, !articleCode.isEmpty {
                    Text(articleCode)
                        .font(.caption.monospaced())
                }
                if let date = commande.date {
                    Text(date, format: .dateTime.day().month().year())
                }
                if let fournisseur = commande.fournisseur {
                    Text("· \(fournisseur)")
                }
                Spacer()
                if !commande.numero.isEmpty {
                    Text("N° \(commande.numero)")
                }
                if let bc = commande.bc, !bc.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
