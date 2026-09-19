import Foundation

/// A follow-up entry (comment) attached to a ticket.
struct ITILFollowup: Decodable, Identifiable, Equatable {
    let id: Int
    let content: String
    let date: Date?
    let isPrivate: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case date
        case isPrivate = "is_private"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        date = try container.decodeIfPresent(String.self, forKey: .date)?.glpiDate
        isPrivate = (try container.decodeIfPresent(Int.self, forKey: .isPrivate) ?? 0) != 0
    }
}
