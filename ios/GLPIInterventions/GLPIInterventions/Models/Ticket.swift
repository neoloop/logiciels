import Foundation

/// Full ticket object as returned by `GET /Ticket/{id}`.
/// Unlike search rows, item endpoints use stable, named JSON keys.
struct Ticket: Decodable, Identifiable, Equatable {
    let id: Int
    let name: String
    let content: String
    let status: TicketStatus
    let priority: TicketPriority?
    let date: Date?
    let dateMod: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case content
        case status
        case priority
        case date
        case dateMod = "date_mod"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "(sans titre)"
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        let statusRaw = try container.decodeIfPresent(Int.self, forKey: .status) ?? TicketStatus.new.rawValue
        status = TicketStatus(rawValue: statusRaw) ?? .new
        priority = try container.decodeIfPresent(Int.self, forKey: .priority).flatMap(TicketPriority.init)
        date = try container.decodeIfPresent(String.self, forKey: .date)?.glpiDate
        dateMod = try container.decodeIfPresent(String.self, forKey: .dateMod)?.glpiDate
    }
}
