import Foundation

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case todo = "À faire"
    case inProgress = "En cours"
    case done = "Fait"

    var id: String { rawValue }
}
