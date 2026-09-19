import Foundation

/// Field numbers used by GLPI's `/search/Ticket` endpoint.
///
/// GLPI's search API keys each row by the *search option id* of the field
/// (not its database column name), and those ids are defined per-itemtype
/// and can be shifted by plugins. The values below are the defaults on a
/// stock GLPI install; they are exposed in Settings so a user whose
/// instance differs can correct them without an app update.
struct GLPIFieldMapping: Codable, Equatable {
    var idField = "2"
    var titleField = "1"
    var statusField = "12"
    var priorityField = "3"
    var dateField = "15"
    var dateModField = "19"
    var assignedTechnicianField = "5"

    var forcedDisplayFields: [String] {
        [idField, titleField, statusField, priorityField, dateField, dateModField]
    }

    static let `default` = GLPIFieldMapping()

    private static let storageKey = "glpi.fieldMapping"

    static func loadFromDefaults() -> GLPIFieldMapping {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let mapping = try? JSONDecoder().decode(GLPIFieldMapping.self, from: data)
        else {
            return .default
        }
        return mapping
    }

    func saveToDefaults() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
