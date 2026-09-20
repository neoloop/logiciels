import Foundation

enum GraphExcelError: LocalizedError {
    case invalidURL
    case httpError(status: Int, message: String)
    case decodingError
    case missingStatusColumn

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Chemin de fichier Excel invalide. Vérifiez les Réglages."
        case .httpError(let status, let message):
            return "Erreur Microsoft Graph (\(status)) : \(message)"
        case .decodingError:
            return "Réponse inattendue de Microsoft Graph."
        case .missingStatusColumn:
            return "Le tableau Excel ne contient pas de colonne \"Statut\". Ajoutez-la (voir README)."
        }
    }
}

/// Lit et met à jour les lignes du tableau Excel des demandes de matériel, via
/// l'API Workbook de Microsoft Graph (le fichier reste un .xlsx classique sur
/// OneDrive/SharePoint, aucun parsing binaire n'est nécessaire). Le tableau peut
/// être alimenté par un formulaire externe utilisé par les employés : les colonnes
/// sont donc identifiées par leur nom d'en-tête (voir ColumnMap), pas par position.
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

    /// Lit la ligne d'en-têtes du tableau, pour faire correspondre les colonnes
    /// réelles (potentiellement créées par un formulaire externe) aux champs
    /// attendus par l'app.
    func fetchColumnMap(accessToken: String, config: AppConfig) async throws -> ColumnMap {
        let url = try tableBaseURL(config: config).appendingPathComponent("headerRowRange")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(data: data, response: response)

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let values = json["values"] as? [[Any]],
            let headerRow = values.first
        else {
            throw GraphExcelError.decodingError
        }
        return ColumnMap(headers: headerRow.map { "\($0)" })
    }

    /// Récupère toutes les lignes du tableau, déjà réparties en demandes exploitables
    /// par l'app (avec l'index de ligne d'origine, nécessaire pour une mise à jour).
    func fetchRequests(accessToken: String, config: AppConfig) async throws -> (columnMap: ColumnMap, rows: [ExcelEquipmentRequestRow]) {
        let columnMap = try await fetchColumnMap(accessToken: accessToken, config: config)

        let url = try tableBaseURL(config: config).appendingPathComponent("rows")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(data: data, response: response)

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = json["value"] as? [[String: Any]]
        else {
            throw GraphExcelError.decodingError
        }

        let rows: [ExcelEquipmentRequestRow] = items.compactMap { item in
            guard
                let index = item["index"] as? Int,
                let values = item["values"] as? [[Any]],
                let rawValues = values.first
            else { return nil }
            return ExcelEquipmentRequestRow(index: index, rawValues: rawValues, columnMap: columnMap)
        }
        return (columnMap, rows.sorted { $0.index > $1.index })
    }

    /// Ajoute une ligne à la fin du tableau Excel pour une demande saisie
    /// manuellement dans l'app (déjà validée à la création).
    func addRow(_ request: EquipmentRequest, columnMap: ColumnMap, accessToken: String, config: AppConfig) async throws {
        var values = [String](repeating: "", count: max(columnMap.count, 1))
        func set(_ candidates: [String], _ value: String) {
            if let i = columnMap.index(forAnyOf: candidates), i < values.count {
                values[i] = value
            }
        }
        set(ExcelColumn.date, EquipmentRequest.dateFormatter.string(from: request.date))
        set(ExcelColumn.requesterName, request.requesterName)
        set(ExcelColumn.requesterEmail, request.requesterEmail)
        set(ExcelColumn.beneficiaryName, request.beneficiaryName)
        set(ExcelColumn.beneficiaryEmail, request.beneficiaryEmail)
        set(ExcelColumn.equipment, request.equipmentLabel)
        set(ExcelColumn.justification, request.justification)
        set(ExcelColumn.status, RequestStatus.validated.rawValue)

        let url = try tableBaseURL(config: config).appendingPathComponent("rows/add")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["values": [values]]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try Self.validate(data: data, response: response)
    }

    /// Met à jour le statut d'une ligne existante (Validée / Refusée), en renvoyant
    /// le reste de ses valeurs inchangé pour ne pas perdre d'éventuelles colonnes
    /// supplémentaires (horodatage, ID de réponse...) ajoutées par le formulaire externe.
    func updateStatus(
        _ newStatus: RequestStatus,
        for row: ExcelEquipmentRequestRow,
        columnMap: ColumnMap,
        accessToken: String,
        config: AppConfig
    ) async throws {
        guard let statusIndex = columnMap.index(forAnyOf: ExcelColumn.status) else {
            throw GraphExcelError.missingStatusColumn
        }

        var newValues = row.rawValues
        while newValues.count <= statusIndex {
            newValues.append("")
        }
        newValues[statusIndex] = newStatus.rawValue

        let url = try tableBaseURL(config: config).appendingPathComponent("rows/itemAt(index=\(row.index))")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PATCH"
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["values": [newValues]]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try Self.validate(data: data, response: response)
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
