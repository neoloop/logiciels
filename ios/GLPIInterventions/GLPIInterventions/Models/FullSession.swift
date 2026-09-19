import Foundation

/// Relevant subset of the response of `GET /getFullSession`.
struct FullSession: Decodable {
    let session: SessionInfo

    enum CodingKeys: String, CodingKey {
        case session
    }

    struct SessionInfo: Decodable {
        let userId: Int
        let userName: String

        enum CodingKeys: String, CodingKey {
            case userId = "glpiID"
            case userName = "glpiname"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            userId = try container.decodeIfPresent(Int.self, forKey: .userId) ?? 0
            userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? ""
        }
    }
}
