import Foundation

/// Abstracts where ticket data comes from, so the UI doesn't need to know
/// whether it's talking live to GLPI (mode "Direct") or reading a periodic
/// JSON export synced via a file share (mode "Fichier partagé").
protocol TicketsRepository: AnyObject {
    /// True when this repository can't perform write operations (e.g. a
    /// static file export). The UI hides/disables status changes and
    /// followups in that case.
    var isReadOnly: Bool { get }

    /// When the data was last refreshed from its source. `nil` if unknown.
    var lastSyncedAt: Date? { get }

    func fetchTicketSummaries(includeClosed: Bool) async throws -> [TicketSummary]
    func fetchTicket(id: Int) async throws -> Ticket
    func fetchFollowups(ticketId: Int) async throws -> [ITILFollowup]
    func updateTicketStatus(id: Int, status: TicketStatus) async throws
    func addFollowup(ticketId: Int, content: String) async throws
}

enum RepositoryError: LocalizedError {
    case readOnly

    var errorDescription: String? {
        switch self {
        case .readOnly:
            return "Action indisponible en mode fichier partagé : repassez en mode Direct (VPN / réseau GLPI) pour modifier un ticket."
        }
    }
}
