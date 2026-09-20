import Foundation
import SwiftData

@Model
final class Dive {
    var date: Date
    var depth: Double
    var durationMinutes: Int
    var buddies: [String]
    var latitude: Double?
    var longitude: Double?
    var locationName: String?
    var notes: String

    init(
        date: Date = .now,
        depth: Double = 0,
        durationMinutes: Int = 0,
        buddies: [String] = [],
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil,
        notes: String = ""
    ) {
        self.date = date
        self.depth = depth
        self.durationMinutes = durationMinutes
        self.buddies = buddies
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.notes = notes
    }

    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }
}
