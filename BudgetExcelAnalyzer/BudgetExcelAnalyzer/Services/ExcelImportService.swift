import CoreXLSX
import Foundation

/// Reads a workbook expected to contain a "Transactions" sheet (Date, Catégorie, Montant,
/// Description) and a "Budget" sheet (Catégorie, Budget) and turns it into typed models.
///
/// Header matching is case- and accent-insensitive and tolerant of a few common synonyms,
/// since real-world exports rarely use exactly the same wording twice.
enum ExcelImportService {

    struct ImportResult {
        let transactions: [Transaction]
        let budgetLines: [BudgetLine]
    }

    private static let transactionSheetNames = ["transactions", "depenses", "operations", "mouvements"]
    private static let budgetSheetNames = ["budget", "budgets"]

    private static let dateHeaders = ["date", "jour"]
    private static let categoryHeaders = ["categorie", "category", "poste"]
    private static let amountHeaders = ["montant", "amount", "somme", "depense"]
    private static let budgetAmountHeaders = ["budget", "montant budgete", "montant mensuel", "amount", "montant"]
    private static let noteHeaders = ["description", "note", "libelle", "commentaire"]

    static func importWorkbook(at url: URL) throws -> ImportResult {
        guard let file = XLSXFile(filepath: url.path) else {
            throw ImportError.cannotOpenFile
        }

        let sharedStrings = try file.parseSharedStrings()
        var transactions: [Transaction] = []
        var budgetLines: [BudgetLine] = []

        for workbook in try file.parseWorkbooks() {
            for entry in try file.parseWorksheetPathsAndNames(workbook: workbook) {
                guard let rawName = entry.name else { continue }
                let normalizedName = ParsingUtils.normalize(rawName)
                let worksheet = try file.parseWorksheet(at: entry.path)
                let rows = worksheet.data?.rows ?? []

                if transactionSheetNames.contains(normalizedName) {
                    transactions = try parseTransactions(rows: rows, sharedStrings: sharedStrings, sheetName: rawName)
                } else if budgetSheetNames.contains(normalizedName) {
                    budgetLines = try parseBudget(rows: rows, sharedStrings: sharedStrings, sheetName: rawName)
                }
            }
        }

        if transactions.isEmpty && budgetLines.isEmpty {
            throw ImportError.noData
        }

        return ImportResult(transactions: transactions, budgetLines: budgetLines)
    }

    // MARK: - Sheet parsing

    private static func parseTransactions(
        rows: [Row],
        sharedStrings: SharedStrings?,
        sheetName: String
    ) throws -> [Transaction] {
        guard let header = rows.first else { return [] }
        let columns = headerColumns(of: header, sharedStrings: sharedStrings)

        guard let dateColumn = firstMatch(dateHeaders, in: columns) else {
            throw ImportError.missingColumn("Date", sheet: sheetName)
        }
        guard let categoryColumn = firstMatch(categoryHeaders, in: columns) else {
            throw ImportError.missingColumn("Catégorie", sheet: sheetName)
        }
        guard let amountColumn = firstMatch(amountHeaders, in: columns) else {
            throw ImportError.missingColumn("Montant", sheet: sheetName)
        }
        let noteColumn = firstMatch(noteHeaders, in: columns)

        var results: [Transaction] = []
        for row in rows.dropFirst() {
            let cells = cellsByColumn(of: row, sharedStrings: sharedStrings)
            guard let dateRaw = cells[dateColumn], let date = ParsingUtils.parseDate(dateRaw) else { continue }
            guard let categoryRaw = cells[categoryColumn] else { continue }
            let category = categoryRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !category.isEmpty else { continue }
            guard let amountRaw = cells[amountColumn], let amount = ParsingUtils.parseAmount(amountRaw) else { continue }
            let note = noteColumn.flatMap { cells[$0] }?.trimmingCharacters(in: .whitespacesAndNewlines)
            results.append(Transaction(date: date, category: category, amount: amount, note: (note?.isEmpty ?? true) ? nil : note))
        }
        return results
    }

    private static func parseBudget(
        rows: [Row],
        sharedStrings: SharedStrings?,
        sheetName: String
    ) throws -> [BudgetLine] {
        guard let header = rows.first else { return [] }
        let columns = headerColumns(of: header, sharedStrings: sharedStrings)

        guard let categoryColumn = firstMatch(categoryHeaders, in: columns) else {
            throw ImportError.missingColumn("Catégorie", sheet: sheetName)
        }
        guard let amountColumn = firstMatch(budgetAmountHeaders, in: columns) else {
            throw ImportError.missingColumn("Budget", sheet: sheetName)
        }

        var results: [BudgetLine] = []
        for row in rows.dropFirst() {
            let cells = cellsByColumn(of: row, sharedStrings: sharedStrings)
            guard let categoryRaw = cells[categoryColumn] else { continue }
            let category = categoryRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !category.isEmpty else { continue }
            guard let amountRaw = cells[amountColumn], let amount = ParsingUtils.parseAmount(amountRaw) else { continue }
            results.append(BudgetLine(category: category, monthlyAmount: amount))
        }
        return results
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
