import Foundation

@MainActor
final class TicketDetailViewModel: ObservableObject {
    @Published private(set) var ticket: Ticket?
    @Published private(set) var followups: [ITILFollowup] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isUpdating = false
    @Published var errorMessage: String?
    @Published var newFollowupText: String = ""

    let ticketId: Int
    let isReadOnly: Bool
    private let repository: TicketsRepository

    init(ticketId: Int, repository: TicketsRepository) {
        self.ticketId = ticketId
        self.repository = repository
        self.isReadOnly = repository.isReadOnly
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            async let ticketFetch = repository.fetchTicket(id: ticketId)
            async let followupsFetch = repository.fetchFollowups(ticketId: ticketId)
            ticket = try await ticketFetch
            followups = try await followupsFetch
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func updateStatus(to status: TicketStatus) async {
        guard ticket != nil else { return }
        guard !isReadOnly else {
            errorMessage = RepositoryError.readOnly.errorDescription
            return
        }
        isUpdating = true
        defer { isUpdating = false }
        do {
            try await repository.updateTicketStatus(id: ticketId, status: status)
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func submitFollowup() async {
        guard !isReadOnly else {
            errorMessage = RepositoryError.readOnly.errorDescription
            return
        }
        let text = newFollowupText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isUpdating = true
        defer { isUpdating = false }
        do {
            try await repository.addFollowup(ticketId: ticketId, content: text)
            newFollowupText = ""
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
