import Foundation

struct Transaction: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let category: String
    let amount: Double
    let note: String?

    init(id: UUID = UUID(), date: Date, category: String, amount: Double, note: String?) {
        self.id = id
        self.date = date
        self.category = category
        self.amount = amount
        self.note = note
    }
}
