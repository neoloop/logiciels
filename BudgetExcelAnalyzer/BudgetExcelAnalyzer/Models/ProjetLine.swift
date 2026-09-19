import Foundation

/// One row of the "PPI" sheet: a multi-year investment project line for a given service.
struct ProjetLine: Identifiable, Codable, Hashable {
    let id: UUID
    let numero: String
    let serviceCode: Int
    let articleCode: String?
    let nom: String
    let budgetAlloue: Double
    let budgetConsomme: Double
    let annee: Date?

    var reste: Double { budgetAlloue - budgetConsomme }

    var percentUsed: Double {
        guard budgetAlloue > 0 else { return budgetConsomme > 0 ? 1 : 0 }
        return min(budgetConsomme / budgetAlloue, 1)
    }

    var isOverBudget: Bool { budgetConsomme > budgetAlloue }

    init(
        id: UUID = UUID(),
        numero: String,
        serviceCode: Int,
        articleCode: String?,
        nom: String,
        budgetAlloue: Double,
        budgetConsomme: Double,
        annee: Date?
    ) {
        self.id = id
        self.numero = numero
        self.serviceCode = serviceCode
        self.articleCode = articleCode
        self.nom = nom
        self.budgetAlloue = budgetAlloue
        self.budgetConsomme = budgetConsomme
        self.annee = annee
    }
}
