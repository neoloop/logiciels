import CoreXLSX
import Foundation

/// Reads a flat budget-execution export (one row per nomenclature line, e.g. a
/// "Situation Budgétaire" export) from the first sheet of the workbook.
///
/// Expected columns (case/accent-insensitive, exact wording otherwise):
///   - "Article Nat. (Code)"            → nomenclature code
///   - "Article Nat. (Libellé)"         → nomenclature label
///   - "Groupe Section (Code)"          → "F" (Fonctionnement) / "I" (Investissement)
///   - "Groupe Chapitre Nat. (Code)"    → chapter code (optional)
///   - "Service Gestionnaire (Code)"    → managing service code
///   - "Service Gestionnaire (Libellé)" → managing service label
///   - "Mt Voté CP"                     → budgeted amount
///   - "Mt Disponible"                  → remaining available amount
///   - any column containing "Demandeur" (Code/Libellé) → requesting service (optional)
///
/// "Engagé" (spent) isn't a source column: it's derived as voté − disponible.
enum ExcelImportService {

    private static let articleCodeHeaders = ["article nat. (code)"]
    private static let articleLabelHeaders = ["article nat. (libelle)"]
    private static let sectionHeaders = ["groupe section (code)"]
    private static let chapitreHeaders = ["groupe chapitre nat. (code)"]
    private static let serviceCodeHeaders = ["service gestionnaire (code)"]
    private static let serviceLabelHeaders = ["service gestionnaire (libelle)"]
    private static let voteHeaders = ["mt vote cp"]
    private static let disponibleHeaders = ["mt disponible"]

    static func importWorkbook(at url: URL) throws -> [BudgetLineItem] {
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

        let columns = headerColumns(of: header, sharedStrings: sharedStrings)

        guard let articleCodeColumn = firstMatch(articleCodeHeaders, in: columns) else {
            throw ImportError.missingColumn("Article Nat. (Code)")
        }
        guard let articleLabelColumn = firstMatch(articleLabelHeaders, in: columns) else {
            throw ImportError.missingColumn("Article Nat. (Libellé)")
        }
        guard let sectionColumn = firstMatch(sectionHeaders, in: columns) else {
            throw ImportError.missingColumn("Groupe Section (Code)")
        }
        guard let serviceCodeColumn = firstMatch(serviceCodeHeaders, in: columns) else {
            throw ImportError.missingColumn("Service Gestionnaire (Code)")
        }
        guard let serviceLabelColumn = firstMatch(serviceLabelHeaders, in: columns) else {
            throw ImportError.missingColumn("Service Gestionnaire (Libellé)")
        }
        guard let voteColumn = firstMatch(voteHeaders, in: columns) else {
            throw ImportError.missingColumn("Mt Voté CP")
        }
        guard let disponibleColumn = firstMatch(disponibleHeaders, in: columns) else {
            throw ImportError.missingColumn("Mt Disponible")
        }
        let chapitreColumn = firstMatch(chapitreHeaders, in: columns)
        let (demandeurCodeColumn, demandeurLabelColumn) = demandeurColumns(in: columns)

        var results: [BudgetLineItem] = []
        for row in rows.dropFirst() {
            let cells = cellsByColumn(of: row, sharedStrings: sharedStrings)

            guard let articleCode = cells[articleCodeColumn]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !articleCode.isEmpty else { continue }
            guard let serviceCodeRaw = cells[serviceCodeColumn],
                  let serviceCode = Int(serviceCodeRaw.trimmingCharacters(in: .whitespacesAndNewlines)) else { continue }

            let articleLabel = cells[articleLabelColumn]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? articleCode
            let section = BudgetSection(code: cells[sectionColumn])
            let serviceLabel = cells[serviceLabelColumn]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Service \(serviceCode)"
            let voté = cells[voteColumn].flatMap(ParsingUtils.parseAmount) ?? 0
            let disponible = cells[disponibleColumn].flatMap(ParsingUtils.parseAmount) ?? 0
            let chapitre = chapitreColumn.flatMap { cells[$0] }?.trimmingCharacters(in: .whitespacesAndNewlines)
            let demandeur = resolveDemandeur(cells: cells, codeColumn: demandeurCodeColumn, labelColumn: demandeurLabelColumn)

            results.append(
                BudgetLineItem(
                    articleCode: articleCode,
                    articleLabel: articleLabel,
                    section: section,
                    chapitreCode: (chapitre?.isEmpty ?? true) ? nil : chapitre,
                    serviceCode: serviceCode,
                    serviceLabel: serviceLabel,
                    demandeur: demandeur,
                    voté: voté,
                    disponible: disponible
                )
            )
        }

        if results.isEmpty {
            throw ImportError.noData
        }
        return results
    }

    // MARK: - "Service demandeur" detection

    /// Mirrors the reference dashboard's logic: find any header containing "demandeur",
    /// then split it into a code column and a label column, whatever their exact wording.
    private static func demandeurColumns(in columns: [String: String]) -> (code: String?, label: String?) {
        let demandeurEntries = columns.filter { $0.value.contains("demandeur") }
        guard !demandeurEntries.isEmpty else { return (nil, nil) }

        let codeColumn = demandeurEntries.first { $0.value.contains("code") }?.key
        let labelColumn = demandeurEntries.first { $0.value.contains("libelle") }?.key
            ?? demandeurEntries.first { $0.key != codeColumn }?.key

        return (codeColumn, labelColumn)
    }

    private static func resolveDemandeur(cells: [String: String], codeColumn: String?, labelColumn: String?) -> String? {
        let code = codeColumn.flatMap { cells[$0] }?.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = labelColumn.flatMap { cells[$0] }?.trimmingCharacters(in: .whitespacesAndNewlines)

        var demandeur = (label?.isEmpty == false) ? label : ((code?.isEmpty == false) ? code : nil)
        if let demandeurValue = demandeur, let code, !code.isEmpty, labelColumn != nil, code != demandeurValue {
            demandeur = "\(code) — \(demandeurValue)"
        }
        return demandeur
    }

    // MARK: - Column helpers

    /// Maps column letters (e.g. "A", "B") to the normalized header text found in that column.
    private static func headerColumns(of row: Row, sharedStrings: SharedStrings?) -> [String: String] {
        var mapping: [String: String] = [:]
        for cell in row.cells {
            guard let text = textValue(of: cell, sharedStrings: sharedStrings) else { continue }
            mapping[columnLetters(of: cell)] = ParsingUtils.normalize(text)
        }
        return mapping
    }

    /// Maps column letters to the raw cell text for a data row.
    private static func cellsByColumn(of row: Row, sharedStrings: SharedStrings?) -> [String: String] {
        var mapping: [String: String] = [:]
        for cell in row.cells {
            mapping[columnLetters(of: cell)] = textValue(of: cell, sharedStrings: sharedStrings)
        }
        return mapping
    }

    /// Resolves a cell's textual/numeric content regardless of whether it's a shared string,
    /// an inline string, or a raw number, without depending on CoreXLSX's exact stringValue
    /// optionality across versions.
    private static func textValue(of cell: Cell, sharedStrings: SharedStrings?) -> String? {
        if let sharedStrings, let resolved = cell.stringValue(sharedStrings) {
            return resolved
        }
        return cell.value
    }

    private static func columnLetters(of cell: Cell) -> String {
        let description = String(describing: cell.reference)
        return String(description.prefix(while: { $0.isLetter }))
    }

    private static func firstMatch(_ candidates: [String], in columns: [String: String]) -> String? {
        for (letters, header) in columns where candidates.contains(header) {
            return letters
        }
        return nil
    }
}
