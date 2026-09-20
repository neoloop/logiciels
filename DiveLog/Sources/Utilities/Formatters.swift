import Foundation

enum DiveFormatters {
    static func duration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours) h \(mins) min"
        }
        return "\(mins) min"
    }

    static func depth(_ meters: Double) -> String {
        String(format: "%.0f m", meters)
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }()
}
