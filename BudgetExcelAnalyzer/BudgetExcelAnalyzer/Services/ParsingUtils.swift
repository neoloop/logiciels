import Foundation

/// Helpers for turning raw, loosely-formatted spreadsheet cell text into typed values.
enum ParsingUtils {

    /// Case- and accent-insensitive normalization used to match header names like
    /// "Libellé" / "libelle" / "LIBELLE" against each other, and to collapse the
    /// stray whitespace some exports leave around column headers.
    static func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    /// Parses amounts written with either a comma or dot decimal separator, optional
    /// currency symbols, and thousands separators (spaces or narrow no-break spaces).
    static func parseAmount(_ raw: String) -> Double? {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        cleaned = cleaned.replacingOccurrences(of: "\u{a0}", with: "")
        cleaned = cleaned.replacingOccurrences(of: "\u{202f}", with: "")
        cleaned = cleaned.replacingOccurrences(of: " ", with: "")
        cleaned.removeAll { "€$£".contains($0) }

        if cleaned.contains(",") && !cleaned.contains(".") {
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        } else {
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        }
        return Double(cleaned)
    }
}
