import Foundation

/// `TicketsRepository` backed by a static JSON file (typically synced via
/// OneDrive by `tools/glpi-onedrive-export`), for when the phone can't
/// reach the GLPI server directly ("mode Fichier partagé").
///
/// Read-only: there is no live connection to push status changes or
/// followups back to GLPI.
final class FileExportRepository: TicketsRepository {
    let isReadOnly = true
    private(set) var lastSyncedAt: Date?

    private let fileURL: URL
    private let urlSession: URLSession
    private var cachedEntries: [TicketExportEntry] = []

    init(fileURL: URL, urlSession: URLSession = .shared) {
        self.fileURL = fileURL
        self.urlSession = urlSession
    }

    func fetchTicketSummaries(includeClosed: Bool) async throws -> [TicketSummary] {
        try await refresh()
        return cachedEntries
            .filter { includeClosed || $0.ticket.status != .closed }
            .map { TicketSummary(ticket: $0.ticket) }
            .sorted { ($0.dateMod ?? .distantPast) > ($1.dateMod ?? .distantPast) }
    }

    func fetchTicket(id: Int) async throws -> Ticket {
        if let entry = cachedEntries.first(where: { $0.ticket.id == id }) {
            return entry.ticket
        }
        try await refresh()
        guard let entry = cachedEntries.first(where: { $0.ticket.id == id }) else {
            throw APIError.http(status: 404, message: "Ce ticket n'est pas (ou plus) présent dans le dernier export.")
        }
        return entry.ticket
    }

    func fetchFollowups(ticketId: Int) async throws -> [ITILFollowup] {
        cachedEntries.first(where: { $0.ticket.id == ticketId })?.followups ?? []
    }

    func updateTicketStatus(id: Int, status: TicketStatus) async throws {
        throw RepositoryError.readOnly
    }

    func addFollowup(ticketId: Int, content: String) async throws {
        throw RepositoryError.readOnly
    }

    /// Always re-downloads: the list view calls this on every load/pull-to-refresh
    /// since the whole point is to see how stale the last export is.
    private func refresh() async throws {
        var request = URLRequest(url: fileURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw APIError.transport(error)
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.http(status: status, message: "Impossible de télécharger le fichier d'export.")
        }

        let decoded: TicketExportFile
        do {
            decoded = try JSONDecoder().decode(TicketExportFile.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }

        cachedEntries = decoded.tickets
        lastSyncedAt = decoded.generatedAt ?? Date()
    }
}
