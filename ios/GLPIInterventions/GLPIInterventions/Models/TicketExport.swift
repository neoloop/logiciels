import Foundation

/// Schema of the JSON file produced by `tools/glpi-onedrive-export` and
/// consumed by `FileExportRepository`. One file per technician.
///
/// Each ticket entry uses exactly the same field names as GLPI's own
/// `GET /Ticket/{id}` response (id, name, content, status, priority, date,
/// date_mod) plus an embedded `followups` array shaped like
/// `GET /Ticket/{id}/ITILFollowup`, so it decodes directly as `Ticket` /
/// `ITILFollowup` with no separate mapping to maintain.
struct TicketExportFile: Decodable {
    let generatedAt: Date?
    let tickets: [TicketExportEntry]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case tickets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try container.decodeIfPresent(String.self, forKey: .generatedAt)?.glpiDate
        tickets = try container.decodeIfPresent([TicketExportEntry].self, forKey: .tickets) ?? []
    }
}

struct TicketExportEntry: Equatable {
    let ticket: Ticket
    let followups: [ITILFollowup]
}

extension TicketExportEntry: Decodable {
    private enum CodingKeys: String, CodingKey {
        case followups
    }

    init(from decoder: Decoder) throws {
        // Same decoder read twice as two different shapes: once for the
        // ticket's own named fields, once for the extra "followups" key.
        // Both are non-consuming keyed-container reads over the same JSON
        // object, which Decodable supports.
        ticket = try Ticket(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        followups = try container.decodeIfPresent([ITILFollowup].self, forKey: .followups) ?? []
    }
}
