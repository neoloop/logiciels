import Foundation

/// Noms de colonnes acceptés pour chaque champ, dans le tableau Excel des
/// demandes. La première variante listée pour chaque champ est celle du
/// tableau réel utilisé (`Demandes_Materiel`, alimenté par un flux Power
/// Automate qui parse un mail structuré) ; les suivantes sont des synonymes
/// acceptés pour rester compatible avec d'autres tableaux. Voir le README.
enum ExcelColumn {
    static let reference = ["Reference", "Référence"]
    static let date = ["Date", "Date de la demande", "Horodateur"]
    static let groupement = ["Groupement", "Groupe", "Service", "Département"]
    static let requesterName = ["Nom_Demandeur", "Demandeur", "Nom du demandeur"]
    static let requesterEmail = ["Mail_Demandeur", "Email demandeur", "E-mail demandeur", "Email"]
    static let beneficiaryName = ["Pour_Qui", "Bénéficiaire", "Nom du bénéficiaire"]
    static let beneficiaryEmail = ["Mail_Pour_Qui", "Email bénéficiaire", "E-mail bénéficiaire"]
    static let phone = ["Telephone", "Téléphone"]
    static let equipment = ["Materiel", "Matériel", "Type de matériel", "Équipement"]
    static let software = ["Logiciels", "Logiciel"]
    static let opportunity = ["Opportunite", "Opportunité"]
    static let status = ["Statut", "Statut de la demande", "État"]
    static let receptionDate = ["Date_Reception", "Date de réception"]
    static let observations = ["Observations", "Justification", "Motif", "Notes"]
}

/// Fait correspondre les en-têtes réelles du tableau Excel (dans leur ordre et
/// intitulé exacts, éventuellement avec des colonnes supplémentaires ajoutées par
/// un formulaire externe) aux champs attendus par l'app, par nom plutôt que par
/// position — ce qui rend l'app tolérante à l'ordre des colonnes ou à des colonnes
/// additionnelles (ex : ID, horodatage ajoutés automatiquement par le flux qui
/// alimente le tableau).
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
