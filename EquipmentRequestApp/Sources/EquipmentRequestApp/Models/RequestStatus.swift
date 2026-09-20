import Foundation

/// Statut d'une demande, tel que stocké dans la colonne "Statut" du tableau Excel.
/// Une case vide ou toute autre valeur que "Validée"/"Refusée" est considérée en attente,
/// ce qui permet au formulaire externe (qui alimente l'Excel) de laisser cette colonne
/// vide à la création sans configuration particulière.
enum RequestStatus: String, CaseIterable {
    case pending = "En attente"
    case validated = "Validée"
    case rejected = "Refusée"

    init(rawStatus: String) {
        let trimmed = rawStatus.trimmingCharacters(in: .whitespacesAndNewlines)
        self = RequestStatus.allCases.first {
            $0.rawValue.caseInsensitiveCompare(trimmed) == .orderedSame
        } ?? .pending
    }
}
