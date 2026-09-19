import Foundation

@MainActor
final class TicketListViewModel: ObservableObject {
    @Published private(set) var tickets: [TicketSummary] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var includeClosed: Bool = false
    @Published var statusFilter: TicketStatus?

    private let client: GLPIAPIClient
    private let currentUserId: Int
    private var mapping: GLPIFieldMapping

    var filteredTickets: [TicketSummary] {
        guard let statusFilter else { return tickets }
        return tickets.filter { $0.status == statusFilter }
    }

    init(client: GLPIAPIClient, currentUserId: Int, mapping: GLPIFieldMapping = .loadFromDefaults()) {
        self.client = client
        self.currentUserId = currentUserId
        self.mapping = mapping
    }

    func refreshMapping() {
        mapping = GLPIFieldMapping.loadFromDefaults()
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await client.searchTickets(
                assignedToUserId: currentUserId,
                includeClosed: includeClosed,
                mapping: mapping
            )
            tickets = result.rows
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
