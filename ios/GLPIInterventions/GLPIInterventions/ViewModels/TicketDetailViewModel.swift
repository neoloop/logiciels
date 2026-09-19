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
    private let client: GLPIAPIClient

    init(ticketId: Int, client: GLPIAPIClient) {
        self.ticketId = ticketId
        self.client = client
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            async let ticketFetch = client.getTicket(id: ticketId)
            async let followupsFetch = client.getFollowups(ticketId: ticketId)
            ticket = try await ticketFetch
            followups = try await followupsFetch
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func updateStatus(to status: TicketStatus) async {
        guard ticket != nil else { return }
        isUpdating = true
        defer { isUpdating = false }
        do {
            try await client.updateTicketStatus(id: ticketId, status: status)
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func submitFollowup() async {
        let text = newFollowupText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isUpdating = true
        defer { isUpdating = false }
        do {
            try await client.addFollowup(ticketId: ticketId, content: text)
            newFollowupText = ""
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
