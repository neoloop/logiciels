import Foundation

/// Persists a security-scoped bookmark to the last file the user picked (typically inside
/// OneDrive via the Files app) so it can be re-read later without prompting the picker again.
enum BookmarkStore {
    private static let bookmarkKey = "budgetExcel.fileBookmark"
    private static let nameKey = "budgetExcel.fileName"

    static func save(url: URL) throws {
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: bookmarkKey)
        UserDefaults.standard.set(url.lastPathComponent, forKey: nameKey)
    }

    static var savedFileName: String? {
        UserDefaults.standard.string(forKey: nameKey)
    }

    static func resolve() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            return nil
        }
        if isStale {
            try? save(url: url)
        }
        return url
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: nameKey)
    }
}
