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

    init(id: Int, title: String, status: TicketStatus, priority: TicketPriority?, date: Date?, dateMod: Date?) {
        self.id = id
        self.title = title
        self.status = status
        self.priority = priority
        self.date = date
        self.dateMod = dateMod
    }

    init?(row: [String: JSONValue], mapping: GLPIFieldMapping) {
        guard
            let idValue = row[mapping.idField]?.intValue
        else { return nil }

        self.init(
            id: idValue,
            title: row[mapping.titleField]?.stringValue ?? "(sans titre)",
            status: row[mapping.statusField]?.intValue.flatMap(TicketStatus.init) ?? .new,
            priority: row[mapping.priorityField]?.intValue.flatMap(TicketPriority.init),
            date: row[mapping.dateField]?.stringValue.glpiDate,
            dateMod: row[mapping.dateModField]?.stringValue.glpiDate
        )
    }
}

extension TicketSummary {
    /// Builds a row from a fully-fetched `Ticket` (used by `FileExportRepository`,
    /// which decodes whole ticket objects rather than search rows).
    init(ticket: Ticket) {
        self.init(
            id: ticket.id,
            title: ticket.name,
            status: ticket.status,
            priority: ticket.priority,
            date: ticket.date,
            dateMod: ticket.dateMod
        )
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
