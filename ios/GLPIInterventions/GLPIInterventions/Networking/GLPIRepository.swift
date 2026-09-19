import Foundation

/// `TicketsRepository` backed by a live GLPI REST session ("mode Direct").
/// Requires the phone to actually be able to reach the GLPI server
/// (same network, or VPN).
final class GLPIRepository: TicketsRepository {
    let isReadOnly = false
    private(set) var lastSyncedAt: Date?

    private let client: GLPIAPIClient
    private let currentUserId: Int
    private let mapping: GLPIFieldMapping

    init(client: GLPIAPIClient, currentUserId: Int, mapping: GLPIFieldMapping = .loadFromDefaults()) {
        self.client = client
        self.currentUserId = currentUserId
        self.mapping = mapping
    }

    func fetchTicketSummaries(includeClosed: Bool) async throws -> [TicketSummary] {
        let result = try await client.searchTickets(
            assignedToUserId: currentUserId,
            includeClosed: includeClosed,
            mapping: mapping
        )
        lastSyncedAt = Date()
        return result.rows
    }

    func fetchTicket(id: Int) async throws -> Ticket {
        try await client.getTicket(id: id)
    }

    func fetchFollowups(ticketId: Int) async throws -> [ITILFollowup] {
        try await client.getFollowups(ticketId: ticketId)
    }

    func updateTicketStatus(id: Int, status: TicketStatus) async throws {
        try await client.updateTicketStatus(id: id, status: status)
    }

    func addFollowup(ticketId: Int, content: String) async throws {
        try await client.addFollowup(ticketId: ticketId, content: content)
    }

    func killSession() async {
        await client.killSession()
    }
}
