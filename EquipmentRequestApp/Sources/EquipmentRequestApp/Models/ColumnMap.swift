import Foundation

/// Noms de colonnes acceptés pour chaque champ, dans le tableau Excel des demandes.
/// Plusieurs variantes sont acceptées car le tableau peut être alimenté par un
/// formulaire externe (Microsoft Forms, Power Automate...) dont on ne maîtrise pas
/// toujours l'intitulé exact des colonnes. Voir le README pour la liste complète.
enum ExcelColumn {
    static let date = ["Date", "Date de la demande", "Horodateur", "Heure de début"]
    static let requesterName = ["Demandeur", "Nom du demandeur", "Nom demandeur"]
    static let requesterEmail = ["Email demandeur", "E-mail demandeur", "Mail demandeur", "Email"]
    static let beneficiaryName = ["Bénéficiaire", "Nom du bénéficiaire", "Pour qui"]
    static let beneficiaryEmail = ["Email bénéficiaire", "E-mail bénéficiaire", "Mail bénéficiaire"]
    static let equipment = ["Matériel", "Type de matériel", "Équipement"]
    static let justification = ["Justification", "Motif", "Raison"]
    static let status = ["Statut", "Statut de la demande", "État"]
}

/// Fait correspondre les en-têtes réelles du tableau Excel (dans leur ordre et
/// intitulé exacts, éventuellement avec des colonnes supplémentaires ajoutées par
/// un formulaire externe) aux champs attendus par l'app, par nom plutôt que par
/// position — ce qui rend l'app tolérante à l'ordre des colonnes ou à des colonnes
/// additionnelles (ex : horodatage, ID de réponse ajoutés automatiquement par
/// Microsoft Forms).
struct ColumnMap {
    let headers: [String]
    private let normalizedIndex: [String: Int]

    init(headers: [String]) {
        self.headers = headers
        var map: [String: Int] = [:]
        for (index, header) in headers.enumerated() {
            map[Self.normalize(header)] = index
        }
        self.normalizedIndex = map
    }

    var count: Int { headers.count }

    func index(forAnyOf candidates: [String]) -> Int? {
        for candidate in candidates {
            if let index = normalizedIndex[Self.normalize(candidate)] {
                return index
            }
        }
        return nil
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .lowercased()
    }
}
