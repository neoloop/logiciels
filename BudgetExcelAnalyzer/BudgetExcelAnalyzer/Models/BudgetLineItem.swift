import Foundation

/// One row of a budget execution export (e.g. "Situation_Budgétaire.xlsx"): a single
/// nomenclature line for a given managing service, with voted vs. available amounts.
/// "Engagé" (spent/committed) is not a column in the source file — it's derived as
/// voté − disponible, exactly like the reference dashboard this app is modeled on.
struct BudgetLineItem: Identifiable, Codable, Hashable {
    let id: UUID
    let articleCode: String
    let articleLabel: String
    let section: BudgetSection
    let chapitreCode: String?
    let serviceCode: Int
    let serviceLabel: String
    let demandeur: String?
    let voté: Double
    let disponible: Double

    var engagé: Double { voté - disponible }

    init(
        id: UUID = UUID(),
        articleCode: String,
        articleLabel: String,
        section: BudgetSection,
        chapitreCode: String?,
        serviceCode: Int,
        serviceLabel: String,
        demandeur: String?,
        voté: Double,
        disponible: Double
    ) {
        self.id = id
        self.articleCode = articleCode
        self.articleLabel = articleLabel
        self.section = section
        self.chapitreCode = chapitreCode
        self.serviceCode = serviceCode
        self.serviceLabel = serviceLabel
        self.demandeur = demandeur
        self.voté = voté
        self.disponible = disponible
    }
}
