import Foundation

/// Lightweight row used in the ticket list, built from a `/search/Ticket`
/// result row using the field ids configured in `GLPIFieldMapping`.
struct TicketSummary: Identifiable, Equatable {
    let id: Int
    let title: String
    let status: TicketStatus
    let priority: TicketPriority?
    let date: Date?
    let dateMod: Date?

    init?(row: [String: JSONValue], mapping: GLPIFieldMapping) {
        guard
            let idValue = row[mapping.idField]?.intValue
        else { return nil }

        self.id = idValue
        self.title = row[mapping.titleField]?.stringValue ?? "(sans titre)"
        self.status = row[mapping.statusField]?.intValue.flatMap(TicketStatus.init) ?? .new
        self.priority = row[mapping.priorityField]?.intValue.flatMap(TicketPriority.init)
        self.date = row[mapping.dateField]?.stringValue.glpiDate
        self.dateMod = row[mapping.dateModField]?.stringValue.glpiDate
    }
}

extension String {
    /// Parses GLPI's default "yyyy-MM-dd HH:mm:ss" datetime format.
    var glpiDate: Date? {
        guard !isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: self)
    }
}
