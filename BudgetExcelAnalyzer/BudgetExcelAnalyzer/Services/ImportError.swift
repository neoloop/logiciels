import Foundation

enum ImportError: LocalizedError {
    case cannotOpenFile
    case emptyWorkbook
    case missingColumn(String)
    case noData

    var errorDescription: String? {
        switch self {
        case .cannotOpenFile:
            return "Impossible d'ouvrir le fichier. Vérifie qu'il s'agit bien d'un fichier .xlsx valide (l'ancien format .xls n'est pas pris en charge : convertis-le d'abord en .xlsx)."
        case .emptyWorkbook:
            return "Le classeur ne contient aucune feuille exploitable."
        case .missingColumn(let name):
            return "La colonne \"\(name)\" est introuvable dans le fichier. Vérifie qu'il s'agit bien d'un export \"Situation Budgétaire\" avec les en-têtes standard."
        case .noData:
            return "Aucune ligne exploitable n'a été trouvée dans le fichier."
        }
    }
}
