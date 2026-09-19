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

    // MARK: - Dates

    private static let excelEpoch: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        // Excel's day-zero, accounting for its historical (incorrect) 1900 leap year.
        return calendar.date(from: DateComponents(year: 1899, month: 12, day: 30))!
    }()

    static func date(fromExcelSerial value: Double) -> Date {
        excelEpoch.addingTimeInterval(value * 86400)
    }

    private static let dateFormatters: [DateFormatter] = {
        let patterns = ["yyyy-MM-dd", "dd/MM/yyyy", "dd-MM-yyyy", "MM/dd/yyyy", "yyyy/MM/dd"]
        return patterns.map { pattern in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = pattern
            return formatter
        }
    }()

    /// Accepts either an Excel numeric date serial (as text) or a handful of common
    /// textual date formats.
    static func parseDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let serial = Double(trimmed) {
            return date(fromExcelSerial: serial)
        }
        for formatter in dateFormatters {
            if let parsed = formatter.date(from: trimmed) {
                return parsed
            }
        }
        return nil
    }

    // MARK: - Leading numeric code

    /// Extracts a leading integer from strings like "58- INFO" or "53-TRANS" (service
    /// codes embedded in a combined code+label column).
    static func leadingInt(_ raw: String) -> Int? {
        let digits = raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix { $0.isNumber }
        return Int(digits)
    }
}
