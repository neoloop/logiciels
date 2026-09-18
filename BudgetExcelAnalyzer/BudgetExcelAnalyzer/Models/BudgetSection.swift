import Foundation

/// French public-accounting budget section: "F" (Fonctionnement) or "I" (Investissement).
enum BudgetSection: String, Codable, Hashable {
    case fonctionnement = "F"
    case investissement = "I"
    case autre

    init(code: String?) {
        switch code?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "F": self = .fonctionnement
        case "I": self = .investissement
        default: self = .autre
        }
    }

    var label: String {
        switch self {
        case .fonctionnement: return "Fonctionnement"
        case .investissement: return "Investissement"
        case .autre: return "Autre"
        }
    }
}
