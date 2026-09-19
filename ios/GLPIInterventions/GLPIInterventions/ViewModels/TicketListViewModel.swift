import Foundation

@MainActor
final class TicketListViewModel: ObservableObject {
    @Published private(set) var tickets: [TicketSummary] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var includeClosed: Bool = false
    @Published var statusFilter: TicketStatus?
    @Published private(set) var lastSyncedAt: Date?

    let isReadOnly: Bool
    private let repository: TicketsRepository

    var filteredTickets: [TicketSummary] {
        guard let statusFilter else { return tickets }
        return tickets.filter { $0.status == statusFilter }
    }

    init(repository: TicketsRepository) {
        self.repository = repository
        self.isReadOnly = repository.isReadOnly
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            tickets = try await repository.fetchTicketSummaries(includeClosed: includeClosed)
            lastSyncedAt = repository.lastSyncedAt
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
