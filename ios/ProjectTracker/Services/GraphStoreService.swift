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

/// Reads/writes the single JSON file (AuthConfig.dataFileName) at the root of OneDrive, used as
/// the entire shared data store between the iOS app and the web page. There is no server: the
/// whole file is downloaded, modified in memory, and re-uploaded on every change — fine for one
/// person using one device at a time, which is this app's scope.
struct GraphStoreService {
    private var contentURL: String {
        "https://graph.microsoft.com/v1.0/me/drive/root:/\(AuthConfig.dataFileName):/content"
    }

    /// nil means the file doesn't exist yet (first run) — callers treat that as an empty store.
    func download(token: String) async throws -> Data? {
        var request = URLRequest(url: URL(string: contentURL)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GraphError.decoding }
        if http.statusCode == 404 { return nil }
        guard (200...299).contains(http.statusCode) else {
            throw GraphError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    func upload(_ data: Data, token: String) async throws {
        var request = URLRequest(url: URL(string: contentURL)!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GraphError.decoding }
        guard (200...299).contains(http.statusCode) else {
            throw GraphError.http(http.statusCode, String(data: responseData, encoding: .utf8) ?? "")
        }
    }
}
