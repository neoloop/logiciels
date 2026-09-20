import Foundation

/// Parses a free-form weekly program message (as typically shared on WhatsApp by a dive club)
/// into a list of candidate planned dives. The result is meant to be reviewed and corrected
/// by the user before being saved — the format used by clubs is too free-form to parse reliably
/// in every case (alternative sites with "ou", combined slots with "+" or "et", missing times…).
enum ProgramTextParser {
    private static let dayWeekdays: [(name: String, weekday: Int)] = [
        ("lundi", 2),
        ("mardi", 3),
        ("mercredi", 4),
        ("jeudi", 5),
        ("vendredi", 6),
        ("samedi", 7),
        ("dimanche", 1)
    ]

    private static let timeRegex = try! NSRegularExpression(pattern: "(\\d{1,2})h(\\d{2})?")

    static func parse(_ text: String, referenceDate: Date = .now, calendar: Calendar = .current) -> [ParsedProgramEntry] {
        var entries: [ParsedProgramEntry] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: CharacterSet(charactersIn: "•-*").union(.whitespaces))
            guard !line.isEmpty, let (weekday, remainder) = extractDay(from: line) else { continue }

            let dayDate = nextDate(forWeekday: weekday, from: referenceDate, calendar: calendar)
            let trimmedRawLine = rawLine.trimmingCharacters(in: .whitespaces)

            for slot in extractSlots(from: remainder) {
                for site in splitAlternatives(slot.siteText) {
                    let trimmedSite = site.trimmingCharacters(in: .whitespaces)
                    guard !trimmedSite.isEmpty else { continue }
                    let dateTime = combine(
                        day: dayDate,
                        hour: slot.hour ?? 9,
                        minute: slot.minute ?? 0,
                        calendar: calendar
                    )
                    entries.append(
                        ParsedProgramEntry(dateTime: dateTime, siteName: trimmedSite, rawLine: trimmedRawLine)
                    )
                }
            }
        }

        return entries
    }

    private static func extractDay(from line: String) -> (weekday: Int, remainder: String)? {
        let lowered = line.lowercased()
        for (name, weekday) in dayWeekdays where lowered.hasPrefix(name) {
            let remainderStart = line.index(line.startIndex, offsetBy: name.count)
            return (weekday, String(line[remainderStart...]))
        }
        return nil
    }

    private struct RawSlot {
        var hour: Int?
        var minute: Int?
        var siteText: String
    }

    private static func extractSlots(from text: String) -> [RawSlot] {
        let nsText = text as NSString
        let matches = timeRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        guard !matches.isEmpty else {
            return [RawSlot(hour: nil, minute: nil, siteText: cleanConnectors(text))]
        }

        var slots: [RawSlot] = []
        for (index, match) in matches.enumerated() {
            let hourRange = match.range(at: 1)
            let minuteRange = match.range(at: 2)
            let hour = hourRange.location != NSNotFound ? Int(nsText.substring(with: hourRange)) : nil
            let minute = minuteRange.location != NSNotFound ? Int(nsText.substring(with: minuteRange)) : nil

            let siteStart = match.range.location + match.range.length
            let siteEnd = index + 1 < matches.count ? matches[index + 1].range.location : nsText.length
            let rawSite = nsText.substring(with: NSRange(location: siteStart, length: max(0, siteEnd - siteStart)))
            slots.append(RawSlot(hour: hour, minute: minute, siteText: cleanConnectors(rawSite)))
        }

        // "10h et 13h30 Ficaghjola" → both slots share the site named after the last time.
        if slots.count > 1 {
            for index in stride(from: slots.count - 2, through: 0, by: -1) where slots[index].siteText.isEmpty {
                slots[index].siteText = slots[index + 1].siteText
            }
        }

        return slots
    }

    private static func cleanConnectors(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespaces)
        for connector in ["et", "+", ","] {
            if result == connector {
                result = ""
            }
            if result.hasPrefix(connector + " ") {
                result = String(result.dropFirst(connector.count)).trimmingCharacters(in: .whitespaces)
            }
            if result.hasSuffix(" " + connector) {
                result = String(result.dropLast(connector.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func splitAlternatives(_ text: String) -> [String] {
        text.components(separatedBy: " ou ")
    }

    private static func nextDate(forWeekday weekday: Int, from referenceDate: Date, calendar: Calendar) -> Date {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let todayWeekday = calendar.component(.weekday, from: startOfToday)
        var diff = weekday - todayWeekday
        if diff < 0 { diff += 7 }
        return calendar.date(byAdding: .day, value: diff, to: startOfToday) ?? startOfToday
    }

    private static func combine(day: Date, hour: Int, minute: Int, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}
