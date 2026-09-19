import Foundation

/// Thin async/await client for the GLPI REST API (apirest.php).
///
/// Reference: https://github.com/glpi-project/glpi/blob/main/apirest.md
actor GLPIAPIClient {
    let config: GLPIConfig
    private var sessionToken: String?
    private let urlSession: URLSession

    init(config: GLPIConfig, urlSession: URLSession = .shared) {
        self.config = config
        self.urlSession = urlSession
    }

    // MARK: - Session lifecycle

    @discardableResult
    func initSession() async throws -> String {
        var request = makeRequest(path: "initSession", method: "GET")
        request.setValue("user_token \(config.userToken)", forHTTPHeaderField: "Authorization")

        let data = try await send(request, requiresSession: false)
        struct Response: Decodable { let session_token: String }
        let response = try decode(Response.self, from: data)
        sessionToken = response.session_token
        return response.session_token
    }

    func killSession() async {
        guard sessionToken != nil else { return }
        let request = makeRequest(path: "killSession", method: "GET")
        _ = try? await send(request, requiresSession: true)
        sessionToken = nil
    }

    func getFullSession() async throws -> FullSession {
        let request = makeRequest(path: "getFullSession", method: "GET")
        let data = try await send(request, requiresSession: true)
        return try decode(FullSession.self, from: data)
    }

    // MARK: - Tickets

    /// Fetches tickets assigned to the given technician using GLPI's generic
    /// search endpoint, ordered by last modification date (most recent first).
    func searchTickets(
        assignedToUserId: Int,
        includeClosed: Bool,
        mapping: GLPIFieldMapping
    ) async throws -> (total: Int, rows: [TicketSummary]) {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "range", value: "0-99"),
            URLQueryItem(name: "sort", value: mapping.dateModField),
            URLQueryItem(name: "order", value: "DESC"),
            URLQueryItem(name: "criteria[0][field]", value: mapping.assignedTechnicianField),
            URLQueryItem(name: "criteria[0][searchtype]", value: "equals"),
            URLQueryItem(name: "criteria[0][value]", value: String(assignedToUserId))
        ]
        for field in mapping.forcedDisplayFields.enumerated() {
            items.append(URLQueryItem(name: "forcedisplay[\(field.offset)]", value: field.element))
        }
        if !includeClosed {
            items.append(contentsOf: [
                URLQueryItem(name: "criteria[1][link]", value: "AND"),
                URLQueryItem(name: "criteria[1][field]", value: mapping.statusField),
                URLQueryItem(name: "criteria[1][searchtype]", value: "notequals"),
                URLQueryItem(name: "criteria[1][value]", value: String(TicketStatus.closed.rawValue))
            ])
        }

        let request = makeRequest(path: "search/Ticket", method: "GET", queryItems: items)
        let data = try await send(request, requiresSession: true)

        struct SearchResponse: Decodable {
            let totalcount: Int
            let data: [[String: JSONValue]]?
        }
        let decoded = try decode(SearchResponse.self, from: data)
        let rows = (decoded.data ?? []).compactMap { TicketSummary(row: $0, mapping: mapping) }
        return (decoded.totalcount, rows)
    }

    func getTicket(id: Int) async throws -> Ticket {
        let request = makeRequest(path: "Ticket/\(id)", method: "GET")
        let data = try await send(request, requiresSession: true)
        return try decode(Ticket.self, from: data)
    }

    func getFollowups(ticketId: Int) async throws -> [ITILFollowup] {
        let items = [
            URLQueryItem(name: "sort", value: "date"),
            URLQueryItem(name: "order", value: "ASC")
        ]
        let request = makeRequest(path: "Ticket/\(ticketId)/ITILFollowup", method: "GET", queryItems: items)
        let data = try await send(request, requiresSession: true)
        return (try? decode([ITILFollowup].self, from: data)) ?? []
    }

    func updateTicketStatus(id: Int, status: TicketStatus) async throws {
        var request = makeRequest(path: "Ticket/\(id)", method: "PUT")
        let body = ["input": ["id": id, "status": status.rawValue]] as [String: [String: Int]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try await send(request, requiresSession: true)
    }

    func addFollowup(ticketId: Int, content: String) async throws {
        var request = makeRequest(path: "Ticket/\(ticketId)/ITILFollowup", method: "POST")
        let body = ["input": ["content": content, "items_id": ticketId, "itemtype": "Ticket"]] as [String: Any]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try await send(request, requiresSession: true)
    }

    // MARK: - Request helpers

    private func makeRequest(path: String, method: String, queryItems: [URLQueryItem] = []) -> URLRequest {
        var url = config.apiBaseURL.appendingPathComponent(path)
        if !queryItems.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = queryItems
            url = components.url!
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(config.appToken, forHTTPHeaderField: "App-Token")
        if let sessionToken {
            request.setValue(sessionToken, forHTTPHeaderField: "Session-Token")
        }
        return request
    }

    private func send(_ request: URLRequest, requiresSession: Bool) async throws -> Data {
        if requiresSession && sessionToken == nil {
            throw APIError.notAuthenticated
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw APIError.transport(error)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.transport(URLError(.badServerResponse))
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                sessionToken = nil
                throw APIError.notAuthenticated
            }
            let message = String(data: data, encoding: .utf8) ?? "réponse inconnue"
            throw APIError.http(status: httpResponse.statusCode, message: message)
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}
