import Foundation

/// Persists a security-scoped bookmark to the last file the user picked (typically inside
/// OneDrive via the Files app) so it can be re-read later without prompting the picker again.
/// `namespace` distinguishes independent imports (e.g. the budget file vs. the commandes file)
/// so each keeps its own remembered file.
enum BookmarkStore {
    private static func bookmarkKey(_ namespace: String) -> String { "budgetExcel.fileBookmark.\(namespace)" }
    private static func nameKey(_ namespace: String) -> String { "budgetExcel.fileName.\(namespace)" }

    static func save(url: URL, namespace: String) throws {
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: bookmarkKey(namespace))
        UserDefaults.standard.set(url.lastPathComponent, forKey: nameKey(namespace))
    }

    static func savedFileName(namespace: String) -> String? {
        UserDefaults.standard.string(forKey: nameKey(namespace))
    }

    static func resolve(namespace: String) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey(namespace)) else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            return nil
        }
        if isStale {
            try? save(url: url, namespace: namespace)
        }
        return url
    }

    static func clear(namespace: String) {
        UserDefaults.standard.removeObject(forKey: bookmarkKey(namespace))
        UserDefaults.standard.removeObject(forKey: nameKey(namespace))
    }
}
