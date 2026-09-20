import Foundation

enum DiveStatus: String, Codable, CaseIterable, Identifiable {
    case planned
    case completed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .planned: return "Planifiée"
        case .completed: return "Réalisée"
        }
    }
}
