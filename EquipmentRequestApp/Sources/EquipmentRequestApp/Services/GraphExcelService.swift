import Foundation

enum GraphExcelError: LocalizedError {
    case invalidURL
    case httpError(status: Int, message: String)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Chemin de fichier Excel invalide. Vérifiez les Réglages."
        case .httpError(let status, let message):
            return "Erreur Microsoft Graph (\(status)) : \(message)"
        case .decodingError:
            return "Réponse inattendue de Microsoft Graph."
        }
    }
}

/// Ajoute et lit des lignes dans le tableau Excel des demandes de matériel,
/// via l'API Workbook de Microsoft Graph (le fichier reste un .xlsx classique
/// sur OneDrive/SharePoint, aucun parsing binaire n'est nécessaire).
struct GraphExcelService {
    private let graphBaseURL = "https://graph.microsoft.com/v1.0"

    /// Construit l'URL de base vers le tableau, ex:
    /// https://graph.microsoft.com/v1.0/me/drive/root:/Demandes/DemandesMateriel.xlsx:/workbook/tables/DemandesMateriel
    private func tableBaseURL(config: AppConfig) throws -> URL {
        let filePath = config.excelFilePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let encodedPath = filePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw GraphExcelError.invalidURL
        }
        let urlString = "\(graphBaseURL)\(config.driveBasePath)/root:/\(encodedPath):/workbook/tables/\(config.tableName)"
        guard let url = URL(string: urlString) else { throw GraphExcelError.invalidURL }
        return url
    }

    /// Ajoute une ligne à la fin du tableau Excel pour la demande validée.
    func addRow(_ request: EquipmentRequest, accessToken: String, config: AppConfig) async throws {
        let url = try tableBaseURL(config: config).appendingPathComponent("rows/add")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["values": [request.excelRow]]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try Self.validate(data: data, response: response)
    }

    /// Récupère les lignes existantes du tableau (les plus récentes en premier),
    /// pour l'onglet Historique.
    func fetchRows(accessToken: String, config: AppConfig) async throws -> [[String]] {
        let url = try tableBaseURL(config: config).appendingPathComponent("rows")
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try Self.validate(data: data, response: response)

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rows = json["value"] as? [[String: Any]]
        else {
            throw GraphExcelError.decodingError
        }

        let parsed: [[String]] = rows.compactMap { row in
            guard let values = row["values"] as? [[Any]], let firstRow = values.first else { return nil }
            return firstRow.map { "\($0)" }
        }
        return parsed.reversed()
    }

    private static func validate(data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0["error"] as? [String: Any])?["message"] as? String }
                ?? String(data: data, encoding: .utf8)
                ?? "Erreur inconnue"
            throw GraphExcelError.httpError(status: httpResponse.statusCode, message: message)
        }
    }
}
