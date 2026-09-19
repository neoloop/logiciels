import Foundation

/// A commande present in one source (Sedit or Expression) but not matched by BC number
/// in the other.
struct BCDiscrepancy: Identifiable, Hashable {
    let id = UUID()
    let bc: String
    let libelle: String
    let montant: Double
    let serviceCode: Int?
    let date: Date?
}

/// Reconciles the Sedit export against the Expression commandes by BC number
/// ("N° Commande" in Sedit, "BC" in Expression).
enum BCReconciliation {

    static func inSeditNotExpression(sedit: [SeditCommandeLine], expression: [CommandeLine]) -> [BCDiscrepancy] {
        let expressionBCs = Set(expression.compactMap(normalizedBC))
        return sedit
            .filter { !expressionBCs.contains(normalize($0.numeroCommande)) }
            .map {
                BCDiscrepancy(bc: $0.numeroCommande, libelle: $0.libelle, montant: $0.montantTTC, serviceCode: $0.serviceCode, date: $0.date)
            }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    static func inExpressionNotSedit(expression: [CommandeLine], sedit: [SeditCommandeLine]) -> [BCDiscrepancy] {
        let seditBCs = Set(sedit.map { normalize($0.numeroCommande) })
        return expression
            .compactMap { commande -> BCDiscrepancy? in
                guard let bc = commande.bc?.trimmingCharacters(in: .whitespacesAndNewlines), !bc.isEmpty else { return nil }
                guard !seditBCs.contains(normalize(bc)) else { return nil }
                return BCDiscrepancy(bc: bc, libelle: commande.libelle, montant: commande.montant, serviceCode: commande.serviceCode, date: commande.date)
            }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    private static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func normalizedBC(_ commande: CommandeLine) -> String? {
        guard let bc = commande.bc?.trimmingCharacters(in: .whitespacesAndNewlines), !bc.isEmpty else { return nil }
        return normalize(bc)
    }
}
