import Foundation

/// Statut d'une demande, tel que stocké dans la colonne "Statut" du tableau
/// Excel. "En attente" et "En cours" correspondent au vocabulaire déjà en
/// usage dans le tableau réel (voir la feuille Statistiques) ; l'app elle-même
/// fait passer une demande directement de "En attente" à "Traité" lors de la
/// validation (pas d'étape intermédiaire "En cours"), mais reconnaît cette
/// valeur si elle existe déjà sur d'anciennes lignes.
/// Une case vide ou toute autre valeur est considérée en attente, ce qui
/// permet au flux qui alimente l'Excel de laisser cette colonne vide à la
/// création sans configuration particulière.
enum RequestStatus: String, CaseIterable {
    case pending = "En attente"
    case inProgress = "En cours"
    case processed = "Traité"
    case rejected = "Refusée"

    init(rawStatus: String) {
        let trimmed = rawStatus.trimmingCharacters(in: .whitespacesAndNewlines)
        self = RequestStatus.allCases.first {
            $0.rawValue.caseInsensitiveCompare(trimmed) == .orderedSame
        } ?? .pending
    }
}
