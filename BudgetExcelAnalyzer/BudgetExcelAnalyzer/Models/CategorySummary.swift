import Foundation

struct CategorySummary: Identifiable {
    var id: String { category }
    let category: String
    let budget: Double?
    let actual: Double

    var remaining: Double? {
        guard let budget else { return nil }
        return budget - actual
    }

    var progress: Double? {
        guard let budget, budget > 0 else { return nil }
        return actual / budget
    }

    var isOverBudget: Bool {
        guard let budget else { return false }
        return actual > budget
    }
}
