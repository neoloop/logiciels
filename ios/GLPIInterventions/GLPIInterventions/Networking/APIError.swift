import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case notAuthenticated
    case http(status: Int, message: String)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL du serveur GLPI invalide."
        case .notAuthenticated:
            return "Session GLPI expirée, veuillez vous reconnecter."
        case .http(let status, let message):
            return "Erreur GLPI (\(status)) : \(message)"
        case .decoding:
            return "Réponse inattendue du serveur GLPI."
        case .transport(let error):
            return "Erreur réseau : \(error.localizedDescription)"
        }
    }
}
