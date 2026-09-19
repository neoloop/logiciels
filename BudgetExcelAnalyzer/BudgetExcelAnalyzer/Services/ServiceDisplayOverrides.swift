import Foundation

/// Presentation-only overrides for known service codes: a friendlier display name and/or a
/// custom position in the services list. Doesn't touch the underlying imported data (the
/// original "Service Gestionnaire (Libellé)" from the file), only how it's shown in the app.
/// Any service code not listed here falls back to the label from the file and is sorted by
/// its numeric code.
enum ServiceDisplayOverrides {
    private static let displayNames: [Int: String] = [
        52: "SIO",
        58: "SIA",
    ]

    /// Lower sorts first. Codes without an explicit rank sort by their own numeric code,
    /// interleaved among the ranked ones; 52 (SIO) is pinned to the very end.
    private static let sortRanks: [Int: Int] = [
        52: .max,
    ]

    static func displayName(forServiceCode code: Int, fallback: String) -> String {
        displayNames[code] ?? fallback
    }

    static func sortRank(forServiceCode code: Int) -> Int {
        sortRanks[code] ?? code
    }
}
