import Foundation

struct Project: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var startDate: Date
    var endDate: Date
    var notes: String

    /// Inclusive day count: a project starting and ending the same day lasts 1 day.
    var durationInDays: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(days + 1, 0)
    }
}
