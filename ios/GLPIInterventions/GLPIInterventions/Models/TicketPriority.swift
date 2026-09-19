import SwiftUI

/// GLPI core ticket priority values.
enum TicketPriority: Int, Codable {
    case veryLow = 1
    case low = 2
    case medium = 3
    case high = 4
    case veryHigh = 5
    case major = 6

    var label: String {
        switch self {
        case .veryLow: return "Très basse"
        case .low: return "Basse"
        case .medium: return "Moyenne"
        case .high: return "Haute"
        case .veryHigh: return "Très haute"
        case .major: return "Majeure"
        }
    }

    var color: Color {
        switch self {
        case .veryLow, .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .veryHigh, .major: return .red
        }
    }
}
