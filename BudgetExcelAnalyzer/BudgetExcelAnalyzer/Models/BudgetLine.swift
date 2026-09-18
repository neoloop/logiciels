import Foundation

struct BudgetLine: Identifiable, Codable, Hashable {
    let id: UUID
    let category: String
    let monthlyAmount: Double

    init(id: UUID = UUID(), category: String, monthlyAmount: Double) {
        self.id = id
        self.category = category
        self.monthlyAmount = monthlyAmount
    }
}
