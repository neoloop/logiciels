import Foundation

struct ProjectTask: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var projectId: String
    var name: String
    var status: TaskStatus
    var order: Int
}
