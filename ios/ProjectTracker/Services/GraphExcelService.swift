import Foundation

enum GraphError: LocalizedError {
    case http(Int, String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .http(let code, let message):
            return "Erreur Microsoft Graph (\(code)) : \(message)"
        case .decoding:
            return "Réponse Microsoft Graph illisible."
        }
    }
}

/// Talks directly to the "ProjectTracker.xlsx" workbook on OneDrive via the Microsoft Graph
/// Excel API. Each table (Projects, Tasks) is addressed by name; rows are addressed by their
/// numeric index, so callers must re-fetch indices after any insert/delete shifts them.
struct GraphExcelService {
    private func request(_ path: String, method: String = "GET", body: [String: Any]? = nil, token: String) async throws -> Data {
        var urlRequest = URLRequest(url: URL(string: AuthConfig.workbookPath + path)!)
        urlRequest.httpMethod = method
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw GraphError.decoding }
        guard (200...299).contains(http.statusCode) else {
            throw GraphError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    /// All rows of a table, each as an array of string cell values in column order.
    func rows(table: String, token: String) async throws -> [[String]] {
        let data = try await request("/tables/\(table)/rows", token: token)
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = json["value"] as? [[String: Any]]
        else { return [] }
        return items.compactMap { item in
            guard let values = item["values"] as? [[Any]], let row = values.first else { return nil }
            return row.map(Self.cellString)
        }
    }

    func addRow(table: String, values: [String], token: String) async throws {
        _ = try await request("/tables/\(table)/rows", method: "POST", body: ["values": [values]], token: token)
    }

    func updateRow(table: String, index: Int, values: [String], token: String) async throws {
        _ = try await request("/tables/\(table)/rows/itemAt(index=\(index))", method: "PATCH", body: ["values": [values]], token: token)
    }

    /// Deleting shifts every following row's index down by one. When removing several rows
    /// from the same table in one go, callers must delete from the highest index to the lowest.
    func deleteRow(table: String, index: Int, token: String) async throws {
        _ = try await request("/tables/\(table)/rows/itemAt(index=\(index))/delete", method: "POST", token: token)
    }

    /// Excel returns numbers as Double even for values written as plain integer strings.
    private static func cellString(_ value: Any) -> String {
        if let number = value as? Double {
            return number == number.rounded() ? String(Int(number)) : String(number)
        }
        if let string = value as? String { return string }
        if let bool = value as? Bool { return bool ? "TRUE" : "FALSE" }
        return ""
    }
}
