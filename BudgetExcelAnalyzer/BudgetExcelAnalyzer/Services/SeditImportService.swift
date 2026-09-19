import CoreXLSX
import Foundation

/// Reads a Sedit "Commandes" export (single flat sheet, one row per order line).
///
/// Expected columns (case/accent-insensitive):
///   - "N° Commande"         → order number, matched against Expression's "BC" column
///   - "Date de la commande" → date (optional)
///   - "Service gestionnaire"→ managing service code (optional)
///   - "Fournisseur"         → supplier (optional)
///   - "Libellé"             → description
///   - "Montant TTC"         → total amount
///   - "Article par nature"  → nomenclature code (optional)
enum SeditImportService {

    private static let numeroCommandeHeaders = ["n° commande"]
    private static let dateHeaders = ["date de la commande"]
    private static let serviceHeaders = ["service gestionnaire"]
    private static let fournisseurHeaders = ["fournisseur"]
    private static let libelleHeaders = ["libelle"]
    private static let montantHeaders = ["montant ttc"]
    private static let articleHeaders = ["article par nature"]

    static func importWorkbook(at url: URL) throws -> [SeditCommandeLine] {
        if url.pathExtension.lowercased() == "xls" {
            throw ImportError.legacyXlsFormat
        }
        guard let file = XLSXFile(filepath: url.path) else {
            throw ImportError.cannotOpenFile
        }

        let sharedStrings = try file.parseSharedStrings()

        guard let workbook = try file.parseWorkbooks().first,
              let firstSheet = try file.parseWorksheetPathsAndNames(workbook: workbook).first else {
            throw ImportError.emptyWorkbook
        }

        let worksheet = try file.parseWorksheet(at: firstSheet.path)
        let rows = worksheet.data?.rows ?? []
        guard let header = rows.first else { throw ImportError.noData }

        let columns = ExcelSheetParsing.headerColumns(of: header, sharedStrings: sharedStrings)

        guard let numeroColumn = ExcelSheetParsing.firstMatch(numeroCommandeHeaders, in: columns) else {
            throw ImportError.missingColumn("N° Commande")
        }
        guard let libelleColumn = ExcelSheetParsing.firstMatch(libelleHeaders, in: columns) else {
            throw ImportError.missingColumn("Libellé")
        }
        let dateColumn = ExcelSheetParsing.firstMatch(dateHeaders, in: columns)
        let serviceColumn = ExcelSheetParsing.firstMatch(serviceHeaders, in: columns)
        let fournisseurColumn = ExcelSheetParsing.firstMatch(fournisseurHeaders, in: columns)
        let montantColumn = ExcelSheetParsing.firstMatch(montantHeaders, in: columns)
        let articleColumn = ExcelSheetParsing.firstMatch(articleHeaders, in: columns)

        var results: [SeditCommandeLine] = []
        for row in rows.dropFirst() {
            let cells = ExcelSheetParsing.cellsByColumn(of: row, sharedStrings: sharedStrings)

            let numero = cells[numeroColumn]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !numero.isEmpty else { continue }

            let libelle = cells[libelleColumn]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let date = dateColumn.flatMap { cells[$0] }.flatMap(ParsingUtils.parseDate)
            let serviceCode = serviceColumn.flatMap { cells[$0] }.flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            let fournisseur = fournisseurColumn.flatMap { cells[$0] }?.trimmingCharacters(in: .whitespacesAndNewlines)
            let montant = montantColumn.flatMap { cells[$0] }.flatMap(ParsingUtils.parseAmount) ?? 0
            let article = articleColumn.flatMap { cells[$0] }?.trimmingCharacters(in: .whitespacesAndNewlines)

            results.append(
                SeditCommandeLine(
                    numeroCommande: numero,
                    date: date,
                    serviceCode: serviceCode,
                    fournisseur: (fournisseur?.isEmpty ?? true) ? nil : fournisseur,
                    libelle: libelle.isEmpty ? numero : libelle,
                    montantTTC: montant,
                    articleCode: (article?.isEmpty ?? true) ? nil : article
                )
            )
        }

        if results.isEmpty {
            throw ImportError.noData
        }
        return results
    }
}
