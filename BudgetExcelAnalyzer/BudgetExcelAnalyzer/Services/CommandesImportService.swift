import CoreXLSX
import Foundation

/// Reads the "Commandes" workbook (e.g. "Comptabilite-Expression"): one "Expression-<service>-
/// <year>" sheet per service holding purchase order lines, plus a "PPI" sheet holding
/// multi-year investment project lines.
///
/// Expected columns (case/accent-insensitive):
///   Commandes sheets ("Expression…"):
///     - "N°Commande", "Date", "Groupe Service Gestionnaire" (e.g. "58- INFO"),
///       "Article Nat", "Libellé", "Montant" or "Montant TTC", "Fournisseur", "BC", "projet"
///   Projets sheet ("PPI…"):
///     - "N°projet", "Service", "Nomenclature", "Projet", "Budget donnée",
///       "budget consomé", "Année"
///
/// "RESTE" isn't read from the file: it's derived as budget donnée − budget consomé.
enum CommandesImportService {

    struct ImportResult {
        let commandes: [CommandeLine]
        let projets: [ProjetLine]
    }

    // Commandes sheet headers
    private static let numeroCommandeHeaders = ["n°commande"]
    private static let dateHeaders = ["date"]
    private static let serviceGestionnaireHeaders = ["groupe service gestionnaire"]
    private static let articleNatHeaders = ["article nat"]
    private static let libelleHeaders = ["libelle"]
    private static let montantHeaders = ["montant ttc", "montant"]
    private static let fournisseurHeaders = ["fournisseur"]
    private static let bcHeaders = ["bc"]
    private static let projetRefHeaders = ["projet"]

    // Projets (PPI) sheet headers
    private static let numeroProjetHeaders = ["n°projet"]
    private static let serviceHeaders = ["service"]
    private static let nomenclatureHeaders = ["nomenclature"]
    private static let nomProjetHeaders = ["projet"]
    private static let budgetAlloueHeaders = ["budget donnee"]
    private static let budgetConsommeHeaders = ["budget consome"]
    private static let anneeHeaders = ["annee"]

    static func importWorkbook(at url: URL) throws -> ImportResult {
        if url.pathExtension.lowercased() == "xls" {
            throw ImportError.legacyXlsFormat
        }
        guard let file = XLSXFile(filepath: url.path) else {
            throw ImportError.cannotOpenFile
        }

        let sharedStrings = try file.parseSharedStrings()

        guard let workbook = try file.parseWorkbooks().first else {
            throw ImportError.emptyWorkbook
        }
        let sheets = try file.parseWorksheetPathsAndNames(workbook: workbook)
        guard !sheets.isEmpty else { throw ImportError.emptyWorkbook }

        var commandes: [CommandeLine] = []
        var projets: [ProjetLine] = []

        for sheet in sheets {
            guard let rawName = sheet.name else { continue }
            let normalizedName = ParsingUtils.normalize(rawName)
            let worksheet = try file.parseWorksheet(at: sheet.path)
            let rows = worksheet.data?.rows ?? []
            guard let header = rows.first else { continue }

            if normalizedName.hasPrefix("expression") {
                commandes += parseCommandes(rows: rows, header: header, sharedStrings: sharedStrings)
            } else if normalizedName.hasPrefix("ppi") {
                projets += parseProjets(rows: rows, header: header, sharedStrings: sharedStrings)
            }
        }

        if commandes.isEmpty && projets.isEmpty {
            throw ImportError.noData
        }
        return ImportResult(commandes: commandes, projets: projets)
    }

    // MARK: - Commandes

    private static func parseCommandes(rows: [Row], header: Row, sharedStrings: SharedStrings?) -> [CommandeLine] {
        let columns = ExcelSheetParsing.headerColumns(of: header, sharedStrings: sharedStrings)

        guard let numeroColumn = ExcelSheetParsing.firstMatch(numeroCommandeHeaders, in: columns),
              let serviceColumn = ExcelSheetParsing.firstMatch(serviceGestionnaireHeaders, in: columns),
              let libelleColumn = ExcelSheetParsing.firstMatch(libelleHeaders, in: columns) else {
            return []
        }
        let dateColumn = ExcelSheetParsing.firstMatch(dateHeaders, in: columns)
        let articleColumn = ExcelSheetParsing.firstMatch(articleNatHeaders, in: columns)
        let montantColumn = ExcelSheetParsing.firstMatch(montantHeaders, in: columns)
        let fournisseurColumn = ExcelSheetParsing.firstMatch(fournisseurHeaders, in: columns)
        let bcColumn = ExcelSheetParsing.firstMatch(bcHeaders, in: columns)
        let projetRefColumn = ExcelSheetParsing.firstMatch(projetRefHeaders, in: columns)

        var results: [CommandeLine] = []
        for row in rows.dropFirst() {
            let cells = ExcelSheetParsing.cellsByColumn(of: row, sharedStrings: sharedStrings)

            let libelle = cells[libelleColumn]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !libelle.isEmpty else { continue }
            guard let serviceRaw = cells[serviceColumn], let serviceCode = ParsingUtils.leadingInt(serviceRaw) else { continue }

            let numero = cells[numeroColumn]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let date = dateColumn.flatMap { cells[$0] }.flatMap(ParsingUtils.parseDate)
            let article = articleColumn.flatMap { cells[$0] }?.trimmingCharacters(in: .whitespacesAndNewlines)
            let montant = montantColumn.flatMap { cells[$0] }.flatMap(ParsingUtils.parseAmount) ?? 0
            let fournisseur = fournisseurColumn.flatMap { cells[$0] }?.trimmingCharacters(in: .whitespacesAndNewlines)
            let bc = bcColumn.flatMap { cells[$0] }?.trimmingCharacters(in: .whitespacesAndNewlines)
            let projetRef = projetRefColumn.flatMap { cells[$0] }?.trimmingCharacters(in: .whitespacesAndNewlines)

            results.append(
                CommandeLine(
                    numero: numero,
                    date: date,
                    serviceCode: serviceCode,
                    serviceLabel: serviceRaw.trimmingCharacters(in: .whitespacesAndNewlines),
                    articleCode: (article?.isEmpty ?? true) ? nil : article,
                    libelle: libelle,
                    montant: montant,
                    fournisseur: (fournisseur?.isEmpty ?? true) ? nil : fournisseur,
                    bc: (bc?.isEmpty ?? true) ? nil : bc,
                    projetRef: (projetRef?.isEmpty ?? true) ? nil : projetRef
                )
            )
        }
        return results
    }

    // MARK: - Projets (PPI)

    private static func parseProjets(rows: [Row], header: Row, sharedStrings: SharedStrings?) -> [ProjetLine] {
        let columns = ExcelSheetParsing.headerColumns(of: header, sharedStrings: sharedStrings)

        guard let numeroColumn = ExcelSheetParsing.firstMatch(numeroProjetHeaders, in: columns),
              let serviceColumn = ExcelSheetParsing.firstMatch(serviceHeaders, in: columns),
              let nomColumn = ExcelSheetParsing.firstMatch(nomProjetHeaders, in: columns) else {
            return []
        }
        let nomenclatureColumn = ExcelSheetParsing.firstMatch(nomenclatureHeaders, in: columns)
        let budgetAlloueColumn = ExcelSheetParsing.firstMatch(budgetAlloueHeaders, in: columns)
        let budgetConsommeColumn = ExcelSheetParsing.firstMatch(budgetConsommeHeaders, in: columns)
        let anneeColumn = ExcelSheetParsing.firstMatch(anneeHeaders, in: columns)

        var results: [ProjetLine] = []
        for row in rows.dropFirst() {
            let cells = ExcelSheetParsing.cellsByColumn(of: row, sharedStrings: sharedStrings)

            let nom = cells[nomColumn]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !nom.isEmpty else { continue }
            guard let serviceRaw = cells[serviceColumn],
                  let serviceCode = Int(serviceRaw.trimmingCharacters(in: .whitespacesAndNewlines)) else { continue }

            let numero = cells[numeroColumn]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let nomenclature = nomenclatureColumn.flatMap { cells[$0] }?.trimmingCharacters(in: .whitespacesAndNewlines)
            let budgetAlloue = budgetAlloueColumn.flatMap { cells[$0] }.flatMap(ParsingUtils.parseAmount) ?? 0
            let budgetConsomme = budgetConsommeColumn.flatMap { cells[$0] }.flatMap(ParsingUtils.parseAmount) ?? 0
            let annee = anneeColumn.flatMap { cells[$0] }.flatMap(ParsingUtils.parseDate)

            results.append(
                ProjetLine(
                    numero: numero,
                    serviceCode: serviceCode,
                    articleCode: (nomenclature?.isEmpty ?? true) ? nil : nomenclature,
                    nom: nom,
                    budgetAlloue: budgetAlloue,
                    budgetConsomme: budgetConsomme,
                    annee: annee
                )
            )
        }
        return results
    }
}
