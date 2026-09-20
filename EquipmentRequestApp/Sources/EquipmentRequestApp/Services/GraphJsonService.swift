import Foundation

enum GraphJsonError: LocalizedError {
    case invalidURL
    case httpError(status: Int, message: String)
    case decodingError
    case conflict

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Chemin de fichier JSON invalide. Vérifiez les Réglages."
        case .httpError(let status, let message):
            return "Erreur Microsoft Graph (\(status)) : \(message)"
        case .decodingError:
            return "Réponse inattendue de Microsoft Graph."
        case .conflict:
            return "La liste des demandes a été modifiée entre-temps (par quelqu'un d'autre, ou depuis une page web). Rechargez et réessayez."
        }
    }
}

/// Lit et écrit le fichier JSON unique qui contient toutes les demandes de
/// matériel, stocké sur OneDrive/SharePoint. Remplace le tableau Excel : plus
/// simple (les champs sont directement typés, pas de correspondance par nom
/// de colonne), mais toute écriture réécrit l'intégralité du fichier — d'où
/// l'usage d'un ETag pour détecter les écritures concurrentes (ex : deux
/// personnes qui valident en même temps depuis l'app et une page web).
struct GraphJsonService {
    private let graphBaseURL = "https://graph.microsoft.com/v1.0"

    private func fileURL(config: AppConfig) throws -> URL {
        let filePath = config.jsonFilePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let encodedPath = filePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw GraphJsonError.invalidURL
        }
        let urlString = "\(graphBaseURL)\(config.driveBasePath)/root:/\(encodedPath):/content"
        guard let url = URL(string: urlString) else { throw GraphJsonError.invalidURL }
        return url
    }

    /// Charge le document. Si le fichier n'existe pas encore sur OneDrive (première
    /// utilisation), retourne un document vide : il sera créé au premier `save`.
    func fetch(accessToken: String, config: AppConfig) async throws -> (document: RequestsDocument, etag: String?) {
        var request = URLRequest(url: try fileURL(config: config))
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
            return (RequestsDocument(), nil)
        }
        try Self.validate(data: data, response: response)

        let etag = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag")
        guard let document = try? JSONDecoder().decode(RequestsDocument.self, from: data) else {
            throw GraphJsonError.decodingError
        }
        return (document, etag)
    }

    /// Enregistre le document complet. `expectedEtag` doit être celui obtenu lors
    /// du dernier `fetch` : si le fichier a changé entre-temps, Microsoft Graph
    /// renvoie 412 et on lève `.conflict` plutôt que d'écraser silencieusement
    /// les modifications de quelqu'un d'autre.
    func save(_ document: RequestsDocument, expectedEtag: String?, accessToken: String, config: AppConfig) async throws {
        var request = URLRequest(url: try fileURL(config: config))
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let expectedEtag {
            request.setValue(expectedEtag, forHTTPHeaderField: "If-Match")
        }
        request.httpBody = try JSONEncoder().encode(document)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 412 {
            throw GraphJsonError.conflict
        }
        try Self.validate(data: data, response: response)
    }

    private static func validate(data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0["error"] as? [String: Any])?["message"] as? String }
                ?? String(data: data, encoding: .utf8)
                ?? "Erreur inconnue"
            throw GraphJsonError.httpError(status: httpResponse.statusCode, message: message)
        }
    }
}
