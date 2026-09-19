import SwiftUI

struct BCDiscrepancyRow: View {
    let discrepancy: BCDiscrepancy

    private var serviceLabel: String {
        guard let code = discrepancy.serviceCode else { return "Service inconnu" }
        return ServiceDisplayOverrides.displayName(forServiceCode: code, fallback: "Service \(code)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(discrepancy.libelle)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Spacer()
                Text(discrepancy.montant.currencyEUR)
            }
            HStack(spacing: 4) {
                Text(serviceLabel)
                    .fontWeight(.semibold)
                if let date = discrepancy.date {
                    Text("· \(date.formatted(date: .abbreviated, time: .omitted))")
                }
                Spacer()
                Text("BC \(discrepancy.bc)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
