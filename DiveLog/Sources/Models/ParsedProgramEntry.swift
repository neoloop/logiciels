import Foundation

struct ParsedProgramEntry: Identifiable {
    let id = UUID()
    var isIncluded: Bool = true
    var dateTime: Date
    var siteName: String
    var rawLine: String
}
