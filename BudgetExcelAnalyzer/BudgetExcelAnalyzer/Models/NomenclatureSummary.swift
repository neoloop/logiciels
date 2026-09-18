import Foundation

/// Amounts aggregated for one nomenclature article (optionally within one service, or
/// consolidated across all services).
struct NomenclatureSummary: Identifiable, Hashable {
    var id: String { articleCode }
    let articleCode: String
    let articleLabel: String
    let section: BudgetSection
    let voté: Double
    let engagé: Double
    let disponible: Double

    var percentEngaged: Double {
        guard voté > 0 else { return engagé > 0 ? 1 : 0 }
        return min(engagé / voté, 1)
    }
}
