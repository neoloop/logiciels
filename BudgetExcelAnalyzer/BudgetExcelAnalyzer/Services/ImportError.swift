import Foundation

enum ImportError: LocalizedError {
    case cannotOpenFile
    case missingColumn(String, sheet: String)
    case noData

    var errorDescription: String? {
        switch self {
        case .cannotOpenFile:
            return "Impossible d'ouvrir le fichier. Vérifie qu'il s'agit bien d'un fichier .xlsx valide."
        case .missingColumn(let name, let sheet):
            return "La colonne \"\(name)\" est introuvable dans la feuille \"\(sheet)\"."
        case .noData:
            return "Aucune donnée exploitable n'a été trouvée. Le classeur doit contenir une feuille \"Transactions\" et/ou une feuille \"Budget\"."
        }
    }
}
