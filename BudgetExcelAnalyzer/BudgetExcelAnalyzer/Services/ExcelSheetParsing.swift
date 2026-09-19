import CoreXLSX
import Foundation

/// Shared low-level helpers for turning a CoreXLSX worksheet row into a column-letter-keyed
/// dictionary of text values. Used by every sheet-specific import service in this app so
/// header matching and cell-value resolution stay consistent across imports.
enum ExcelSheetParsing {

    /// Maps column letters (e.g. "A", "B") to the normalized header text found in that column.
    static func headerColumns(of row: Row, sharedStrings: SharedStrings?) -> [String: String] {
        var mapping: [String: String] = [:]
        for cell in row.cells {
            guard let text = textValue(of: cell, sharedStrings: sharedStrings) else { continue }
            mapping[columnLetters(of: cell)] = ParsingUtils.normalize(text)
        }
        return mapping
    }

    /// Maps column letters to the raw cell text for a data row.
    static func cellsByColumn(of row: Row, sharedStrings: SharedStrings?) -> [String: String] {
        var mapping: [String: String] = [:]
        for cell in row.cells {
            mapping[columnLetters(of: cell)] = textValue(of: cell, sharedStrings: sharedStrings)
        }
        return mapping
    }

    /// Resolves a cell's textual/numeric content regardless of whether it's a shared string,
    /// an inline string, or a raw number, without depending on CoreXLSX's exact stringValue
    /// optionality across versions.
    static func textValue(of cell: Cell, sharedStrings: SharedStrings?) -> String? {
        if let sharedStrings, let resolved = cell.stringValue(sharedStrings) {
            return resolved
        }
        return cell.value
    }

    static func columnLetters(of cell: Cell) -> String {
        let description = String(describing: cell.reference)
        return String(description.prefix(while: { $0.isLetter }))
    }

    static func firstMatch(_ candidates: [String], in columns: [String: String]) -> String? {
        for (letters, header) in columns where candidates.contains(header) {
            return letters
        }
        return nil
    }
}
