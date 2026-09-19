import SwiftUI

/// GLPI core ticket status values (Ticket::STATUS_* constants).
enum TicketStatus: Int, CaseIterable, Codable, Identifiable {
    case new = 1
    case processingAssigned = 2
    case processingPlanned = 3
    case pending = 4
    case solved = 5
    case closed = 6

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .new: return "Nouveau"
        case .processingAssigned: return "En cours (assignée)"
        case .processingPlanned: return "En cours (planifiée)"
        case .pending: return "En attente"
        case .solved: return "Résolu"
        case .closed: return "Clos"
        }
    }

    var color: Color {
        switch self {
        case .new: return .blue
        case .processingAssigned, .processingPlanned: return .orange
        case .pending: return .purple
        case .solved: return .green
        case .closed: return .gray
        }
    }

    /// Statuses a technician can typically move a ticket to from the app.
    static var editableCases: [TicketStatus] {
        [.processingAssigned, .processingPlanned, .pending, .solved]
    }
}
