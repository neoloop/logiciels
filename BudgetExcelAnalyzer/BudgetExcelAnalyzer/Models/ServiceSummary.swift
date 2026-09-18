import Foundation

struct ServiceSummary: Identifiable, Hashable {
    var id: Int { serviceCode }
    let serviceCode: Int
    let serviceLabel: String
    let voté: Double
    let engagé: Double
    let disponible: Double

    var percentEngaged: Double {
        guard voté > 0 else { return engagé > 0 ? 1 : 0 }
        return min(engagé / voté, 1)
    }

    var isOverBudget: Bool { engagé > voté }
}
