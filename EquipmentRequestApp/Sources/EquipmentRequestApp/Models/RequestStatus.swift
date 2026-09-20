import Foundation

/// Statut d'une demande, tel que stocké dans le champ "status" du fichier
/// JSON. "En attente" et "En cours" correspondent au vocabulaire déjà en
/// usage dans l'ancien tableau Excel (voir le README) ; l'app elle-même
/// fait passer une demande directement de "En attente" à "Traité" lors de la
/// validation (pas d'étape intermédiaire "En cours"), mais reconnaît cette
/// valeur si elle existe déjà sur d'anciennes demandes.
/// Une valeur vide ou inconnue est considérée en attente, ce qui permet au
/// formulaire externe de laisser ce champ vide à la création sans
/// configuration particulière.
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
