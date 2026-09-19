import Foundation

/// Holds the last imported Sedit commandes export, with the same local-cache/security-scoped-
/// bookmark pattern as the other stores. Kept separate from CommandesDataStore since it's a
/// third, independent file used only to reconcile BC numbers against the Expression commandes.
@MainActor
final class SeditDataStore: ObservableObject {
    @Published private(set) var commandes: [SeditCommandeLine] = []
    @Published private(set) var lastImportDate: Date?
    @Published private(set) var sourceFileName: String?
    @Published var errorMessage: String?
    @Published var isImporting = false

    private static let bookmarkNamespace = "sedit"

    private let snapshotURL: URL = {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("sedit-snapshot.json")
    }()

    init() {
        loadSnapshot()
    }

    func importFile(from url: URL) async {
        isImporting = true
        errorMessage = nil
        defer { isImporting = false }

        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        do {
            let items = try await Task.detached(priority: .userInitiated) {
                try Self.readCoordinated(at: url)
            }.value

            try BookmarkStore.save(url: url, namespace: Self.bookmarkNamespace)

            commandes = items
            lastImportDate = Date()
            sourceFileName = url.lastPathComponent
            saveSnapshot()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshFromSavedBookmark() async {
        guard let url = BookmarkStore.resolve(namespace: Self.bookmarkNamespace) else {
            errorMessage = "Aucun fichier enregistré. Importe à nouveau ton fichier Sedit."
            return
        }
        await importFile(from: url)
    }

    func autoRefreshIfPossible() async {
        guard let url = BookmarkStore.resolve(namespace: Self.bookmarkNamespace) else { return }
        await importFile(from: url)
    }

    nonisolated private static func readCoordinated(at url: URL) throws -> [SeditCommandeLine] {
        var coordinatorError: NSError?
        var result: Result<[SeditCommandeLine], Error>?

        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinatorError) { coordinatedURL in
            result = Result { try SeditImportService.importWorkbook(at: coordinatedURL) }
        }

        if let coordinatorError {
            throw coordinatorError
        }
        guard let result else {
            throw ImportError.cannotOpenFile
        }
        return try result.get()
    }

    // MARK: - Local snapshot persistence

    private struct Snapshot: Codable {
        let commandes: [SeditCommandeLine]
        let lastImportDate: Date
        let sourceFileName: String
    }

    private func saveSnapshot() {
        guard let sourceFileName, let lastImportDate else { return }
        let snapshot = Snapshot(commandes: commandes, lastImportDate: lastImportDate, sourceFileName: sourceFileName)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: snapshotURL, options: .atomic)
    }

    private func loadSnapshot() {
        guard let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        commandes = snapshot.commandes
        lastImportDate = snapshot.lastImportDate
        sourceFileName = snapshot.sourceFileName
    }
}
