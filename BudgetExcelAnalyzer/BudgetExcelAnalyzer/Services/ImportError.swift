import Foundation

enum ImportError: LocalizedError {
    case legacyXlsFormat
    case cannotOpenFile
    case emptyWorkbook
    case missingColumn(String)
    case noData

    var errorDescription: String? {
        switch self {
        case .legacyXlsFormat:
            return "Ce fichier est au format .xls (ancien format Excel), qui n'est pas pris en charge. Ouvre-le dans Excel, Numbers ou OneDrive Online et enregistre-le au format .xlsx, puis réimporte-le."
        case .cannotOpenFile:
            return "Impossible d'ouvrir le fichier. Vérifie qu'il s'agit bien d'un fichier .xlsx valide et non corrompu."
        case .emptyWorkbook:
            return "Le classeur ne contient aucune feuille exploitable."
        case .missingColumn(let name):
            return "La colonne \"\(name)\" est introuvable dans le fichier. Vérifie qu'il s'agit bien d'un export \"Situation Budgétaire\" avec les en-têtes standard."
        case .noData:
            return "Aucune ligne exploitable n'a été trouvée dans le fichier."
        }
    }
}
