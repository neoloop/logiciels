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
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
